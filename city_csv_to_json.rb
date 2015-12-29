require 'csv'
require 'fileutils'
require 'json'

# converts building and points csv files to a JSON format
# ruby city_csv_to_json.rb e:\insight-center\portland\portland_bldg_footprints.csv e:\insight-center\portland\portland_bldg_points.csv city.json

buildings_csv = ARGV[0]
points_csv = ARGV[1]
out_json = ARGV[2]

if !File.exists?(buildings_csv)
  raise "buildings_csv = #{buildings_csv} does not exist"
end

if !File.exists?(points_csv)
  raise "points_csv = #{points_csv} does not exist"
end

CSV::Converters[:blank_to_nil] = lambda do |field|
  field && field.empty? ? nil : field
end

# this class can be extended per city if needed
class Taxlot
  def initialize(row, all_points)
    @row = row
    @all_points = all_points
  end
  
  def to_hash
    taxlot = {}
    taxlot[:id] = @row[:taxlot_id].to_s if !@row[:taxlot_id].nil?
    taxlot[:source_id] = @row[:taxlot_id].to_s if !@row[:taxlot_id].nil?
    
    taxlot.each {|key,value| building.delete(key) if value.nil? } 
    
    return taxlot
  end
end

# this class can be extended per city if needed
class Building

  def initialize(row, all_points)
    @row = row
    @all_points = all_points
    @last_space_type_source = nil
    @last_number_of_stories_source = nil
    @last_number_of_stories_above_ground = nil
    @last_number_of_stories_above_ground_source = nil
    @last_number_of_stories_below_ground = nil
    @last_number_of_stories_below_ground_source = nil
    @last_number_of_residential_units_source = nil
    @last_year_built_source = nil
    @last_structure_type_source = nil
    @last_height_source = nil
    @last_roof_type_source = nil
    @last_floor_area_source = nil
    @assumed_floor_to_floor_height = 3.65 # assume 12 ft
  end
  
  def id
    @row[:bldg_fid].nil? ? nil : @row[:bldg_fid].to_s
  end
  
  def source_id
    @row[:bldg_id].nil? ? nil : @row[:bldg_id].to_s
  end
  
  def taxlot_id
    @row[:taxlot_id].nil? ? nil : @row[:taxlot_id].to_s
  end  
  
  def building_number
    @row[:bldg_numb].nil? ? nil : @row[:bldg_numb].to_i
  end  
  
  def name
    @row[:bldg_name].nil? ? nil : @row[:bldg_name].to_s
  end  
  
  def address
    @row[:bldg_addr].nil? ? nil : @row[:bldg_addr].to_s
  end  
  
  def status
    @row[:bldg_stat].nil? ? nil : @row[:bldg_stat].to_s
  end  
  
  def space_type
    space_use = @row[:bldg_use]

    if space_use.nil?
      @last_space_type_source = "Inferred"
      
      zone = @row[:zone]
      if zone.nil?
        if bldg_footprint_m2 > 300 
          space_use = "Commercial Office"
        else
          space_use = "Single Family Residential"
        end
      elsif /R/.match(zone)
        if @row[:bldg_footprint_m2] > 300 
          space_use = "Multi Family Residential"
        else
          space_use = "Single Family Residential"
        end
      else
        space_use = "Commercial Office"
      end
    else
      @last_space_type_source = "Assessor"
    end
    
    cbecs_space_use = nil
    if space_use == "Multi Family Residential"
      if @row[:units_res]
        if @row[:units_res].to_i <= 4
          cbecs_space_use= "Multifamily (2 to 4 units)"
        else
          cbecs_space_use= "Multifamily (5 or more units)"
        end
      else
        if @row[:bldg_footprint_m2] > 800
          cbecs_space_use= "Multifamily (5 or more units)"
        else
          cbecs_space_use= "Multifamily (2 to 4 units)"
        end
      end
    elsif space_use == "Single Family Residential"
      cbecs_space_use= "Single-Family"
    elsif space_use == "Commercial Grocery"
      cbecs_space_use = "Food sales"
    elsif space_use == "Commercial Hotel"
      cbecs_space_use = "Lodging"
    elsif space_use == "Commercial Office"
      cbecs_space_use = "Office"
    elsif space_use == "Commercial Restaurant"
      cbecs_space_use = "Food service"
    elsif space_use == "Commercial Retail"
      cbecs_space_use = "Retail other than mall"
    elsif space_use == "Industrial"   
      cbecs_space_use = "Nonrefrigerated warehouse"
    elsif space_use == "Institutional"    
      cbecs_space_use = "Office"      
    elsif space_use == "Institutional Religious"    
      cbecs_space_use = "Religious worship"
    elsif space_use == "Parking"    
      cbecs_space_use = "Other"
    elsif space_use == "Vacant"    
      cbecs_space_use = "Vacant"
    else
      raise "Unknown space_use '#{space_use}'"
    end
    
    return cbecs_space_use
  end
  
  def space_type_source
    return @last_space_type_source 
  end
  
  def number_of_stories
    result = @row[:num_story]
    
    if result.nil?
      @last_number_of_stories_source = "Inferred"
      
      num_floors_height = nil
      if @row[:roof_elev_m] && @row[:surf_elev_m]
        height = @row[:roof_elev_m].to_f - @row[:surf_elev_m].to_f
        num_floors_height = height / @assumed_floor_to_floor_height
      end
      
      num_floors_area = nil
      if @row[:bldg_area_m2] && @row[:bldg_footprint_m2]
        num_floors_area = @row[:bldg_area_m2].to_f / @row[:bldg_footprint_m2].to_f
      end
      
      if num_floors_height && num_floors_area
        result = num_floors_area.round # prefer the area based weighting as height based metric does not include basements
      elsif num_floors_height
        result = num_floors_height.round
      elsif num_floors_area
        result = num_floors_area.round
      else
        result = 1
        puts "No number_of_stories information for building #{@row[:bldg_fid]}"
      end

    else
      result = result.to_i
      @last_number_of_stories_source = "Assessor"
    end
    
    # check that our resulting floor area is not too much larger than the reported area
    if @row[:bldg_footprint_m2] && @row[:bldg_area_m2]
      resulting_area = @row[:bldg_footprint_m2] * result
      if resulting_area > 1.2 * @row[:bldg_area_m2]
        new_result = [1, result - 1].max
        new_resulting_area = @row[:bldg_footprint_m2] * new_result
        if (@row[:bldg_area_m2]-new_resulting_area).abs < (@row[:bldg_area_m2]-resulting_area).abs
          result = new_result
          @last_number_of_stories_source = "Inferred"
        end
      end
    end
    
    # now try to figure out number of above and below ground surfaces
    if @row[:roof_elev_m] && @row[:surf_elev_m] && result > 1
      floor_to_floor_height_no_basement = (@row[:roof_elev_m] - @row[:surf_elev_m]) / result
      floor_to_floor_height_with_basement = (@row[:roof_elev_m] - @row[:surf_elev_m]) / (result - 1)
      if (floor_to_floor_height_no_basement - @assumed_floor_to_floor_height).abs < (floor_to_floor_height_with_basement - @assumed_floor_to_floor_height).abs
        @last_number_of_stories_above_ground = result
        @last_number_of_stories_above_ground_source = "Inferred"
        @last_number_of_stories_below_ground = 0
        @last_number_of_stories_below_ground_source = "Inferred"
      else
        @last_number_of_stories_above_ground = result-1
        @last_number_of_stories_above_ground_source = "Inferred"
        @last_number_of_stories_below_ground = 1
        @last_number_of_stories_below_ground_source = "Inferred"
      end
    else
      @last_number_of_stories_above_ground = result
      @last_number_of_stories_above_ground_source = "Inferred"
      @last_number_of_stories_below_ground = 0
      @last_number_of_stories_below_ground_source = "Inferred"
    end
    
    return result
  end
  
  def number_of_stories_source
    return @last_number_of_stories_source
  end
  
  def number_of_stories_above_ground
    return @last_number_of_stories_above_ground
  end
  
  def number_of_stories_above_ground_source
    return @last_number_of_stories_above_ground_source
  end
  
  def number_of_stories_below_ground
    return @last_number_of_stories_below_ground
  end
  
  def number_of_stories_below_ground_source
    return @last_number_of_stories_below_ground_source
  end
  
  def number_of_residential_units
    result = @row[:units_res]
    
    if result.nil?
      @last_number_of_residential_units_source = "Inferred"
      
      area = nil
      if @row[:bldg_area_m2]
        area = @row[:bldg_area_m2]
      elsif @row[:bldg_footprint_m2]
        area = @row[:bldg_footprint_m2]*number_of_stories
      end
      
      space_use = space_type
      if space_use == "Multifamily (2 to 4 units)"
        if area
          result = (area / 140).round # 1500 ft^2 / unit
          if result > 4
            result = 4
          elsif result < 2
            result = 2
          end
        else
          result = 2
        end
      elsif space_use == "Multifamily (5 or more units)"
        if area
          result = (area / 92).round # 1000 ft^2 / unit
          if result < 5
            result = 5
          end
        else
          result = 5
        end
      elsif space_use == "Single-Family"
        result = 1
      elsif space_use == "Mobile Home"
        result = 1
      else
        result = 0
      end
      
    else
      result = result.to_i
      @last_number_of_residential_units_source = "Assessor"
    end
    
    return result
  end
  
  def number_of_residential_units_source
    return @last_number_of_residential_units_source
  end
  
  def year_built
    @row[:year_built].nil? ? nil : @row[:year_built].to_i
  end  
  
  def year_built_source
    result = nil
    if !@row[:year_built].nil?
      result = "Assessor"
    end
    return result
  end  
  
  def structure_type
    @row[:struc_type].nil? ? nil : @row[:struc_type].to_s
  end  
  
  def structure_type_source
    result = nil
    if !@row[:struc_type].nil?
      result = "Assessor"
    end
    return result
  end
  
  def structure_condition
    @row[:struc_cond].nil? ? nil : @row[:struc_cond].to_s
  end
  
  def structure_condition_source
    result = nil
    if !@row[:struc_cond].nil?
      result = "Assessor"
    end
    return result
  end
  
  def average_roof_height
    @row[:avg_height_m].nil? ? nil : @row[:avg_height_m]
  end
  
  def average_roof_height_source
    result = nil
    if !@row[:avg_height_m].nil?
      result = "Measured"
    end
    return result
  end
  
  def maximum_roof_height
    @row[:max_height_m].nil? ? nil : @row[:max_height_m]
  end 
  
  def maximum_roof_height_source
    result = nil
    if !@row[:max_height_m].nil?
      result = "Measured"
    end
    return result
  end
  
  def minimum_roof_height
    @row[:min_height_m].nil? ? nil : @row[:min_height_m]
  end
  
  def minimum_roof_height_source
    result = nil
    if !@row[:min_height_m].nil?
      result = "Measured"
    end
    return result
  end
  
  def surface_elevation
    result = @row[:surf_elev_m]
    
    if result.nil?
      @last_roof_elevation_source = "Inferred"
      
      if @row[:roof_elev_m]
        result = @row[:roof_elev_m].to_f - number_of_stories*@assumed_floor_to_floor_height
      else
        result = 0
      end
      
    else
      @last_surface_elevation_source = "Measured"
    end
    
    return result
  end
  
  def surface_elevation_source
    return @last_surface_elevation_source
  end
  
  def roof_elevation
    result = @row[:roof_elev_m]
    
    if result.nil?
      @last_roof_elevation_source = "Inferred"
      result = surface_elevation + number_of_stories*@assumed_floor_to_floor_height
    else
      @last_roof_elevation_source = "Measured"
    end
    
    return result
  end
  
  def roof_elevation_source
    return @last_roof_elevation_source
  end
  
  def roof_type
    result = @row[:roof_type].nil? ? nil : @row[:roof_type].to_s
    if result == "Asphalt Shingle"
      result = nil
    elsif result == "Wood Shake"
      result = nil
    elsif result == "Metal"
      result = nil
    elsif result == "Multi-level"
      result = "Multi-level Flat"
    end
    return result
  end  
  
  def roof_type_source
    result = nil
    if roof_type && !@row[:roof_type].nil?
      result = "Assessor"
    end
    return result
  end  
  
  def floor_area
    @row[:bldg_area_m2].nil? ? nil : @row[:bldg_area_m2]
  end  
  
  def floor_area_source
    result = nil
    if !@row[:bldg_area_m2].nil?
      result = "Assessor"
    end
    return result
  end  
  
  def intersecting_building_ids
    result = []
    if !@row[:intersecting_bldg_fid].nil? 
      if (md = /\[(.*)\]/.match(@row[:intersecting_bldg_fid].to_s))
        md[1].split(',').each do |id|
          result << id.to_s.strip
        end
      end
    end
    return result
  end  
  
  def surrounding_building_ids
    result = []
    if !@row[:surrounding_building_id].nil? 
      if (md = /\[(.*)\]/.match(@row[:surrounding_building_id].to_s))
        md[1].split(',').each do |id|
          result << id.to_s.strip
        end
      end
    end
    return result
  end  
  
  def footprint
    this_id = @row[:bldg_fid]
    points = @all_points.select{|p| p[:bldg_fid] == this_id}
    
    multi_part_plygn_indices = points.collect {|p| p[:multi_part_plygn_index] }.uniq
    plygn_indices = points.collect {|p| p[:plygn_index] }.uniq
    
    footprint = {}
    footprint[:area] = @row[:bldg_footprint_m2]
    footprint[:perimeter] = @row[:bldg_perimeter_m]
    footprint[:polygons] = []
    multi_part_plygn_indices.sort.each do |multi_part_plygn_index|
      plygn_indices.sort.each do |plygn_index|
        this_points = points.select{|p| p[:multi_part_plygn_index] == multi_part_plygn_index && p[:plygn_index] == plygn_index}
        this_points.sort!{|x,y| x[:point_order] <=> y[:point_order]}
        next if this_points.empty?
        
        hole_index = plygn_index - 2
        
        wgs84_index = 2*(multi_part_plygn_index-1)
        cartesian_index = wgs84_index + 1
        
        this_points.each do |point|
        
          wgs84_x = nil
          wgs84_y = nil
          if md = /\[(.*),(.*)\]/.match(point[:point_xy_4326])
            wgs84_x = md[1].to_f
            wgs84_y = md[2].to_f
          end

          cartesian_x = nil
          cartesian_y = nil
          if md = /\[(.*),(.*)\]/.match(point[:point_xy_26910])
            cartesian_x = md[1].to_f
            cartesian_y = md[2].to_f
          end
          
          if plygn_index == 1
            #outer polygon
            if footprint[:polygons][wgs84_index].nil?
              footprint[:polygons][wgs84_index] = {} 
              footprint[:polygons][wgs84_index][:coordinate_system] = "WGS 84"
              footprint[:polygons][wgs84_index][:points] = []
              footprint[:polygons][wgs84_index][:holes] = []
            end
            if footprint[:polygons][cartesian_index].nil?
              footprint[:polygons][cartesian_index] = {} 
              footprint[:polygons][cartesian_index][:coordinate_system] = "Local Cartesian"
              footprint[:polygons][cartesian_index][:points] = []
              footprint[:polygons][cartesian_index][:holes] = []
            end
            
            footprint[:polygons][wgs84_index][:points] << {:x => wgs84_x, :y => wgs84_y}
            footprint[:polygons][cartesian_index][:points] << {:x => cartesian_x, :y => cartesian_y}
            
          else
            # hole
            if footprint[:polygons][wgs84_index][:holes][hole_index].nil?
              footprint[:polygons][wgs84_index][:holes][hole_index] = {:points => []}
            end            
            if footprint[:polygons][cartesian_index][:holes][hole_index].nil?
              footprint[:polygons][cartesian_index][:holes][hole_index] = {:points => []}
            end
            
            footprint[:polygons][wgs84_index][:holes][hole_index][:points] << {:x => wgs84_x, :y => wgs84_y}
            footprint[:polygons][cartesian_index][:holes][hole_index][:points] << {:x => cartesian_x, :y => cartesian_y}
          end
        end
      end
    end
    
    return footprint
  end
  
  def window_to_wall_ratio
    return 0.4
  end
  
  def stories 
    result = []
    st = space_type
    fp = footprint
    wwr = window_to_wall_ratio
    below_ground = number_of_stories_below_ground
    above_ground = number_of_stories_above_ground
    elevation = surface_elevation - @assumed_floor_to_floor_height*below_ground

    ((-below_ground+1)..above_ground).each do |story_number|
      name = "Bldg #{@row[:bldg_fid]} Story #{story_number}"
      result << {:name => name, :story_number => story_number, :floor_to_floor_height => @assumed_floor_to_floor_height, :elevation => elevation, :window_to_wall_ratio => wwr, :space_type => st, :footprint => fp}
      elevation += @assumed_floor_to_floor_height
    end
    
    return result
  end
  
  def to_hash
    building = {}
    building[:id] = id
    building[:source_id] = source_id
    building[:taxlot_id] = taxlot_id
    building[:building_number] = building_number
    building[:name] = name
    building[:address] = address
    building[:status] = status
    building[:space_type] = space_type
    building[:space_type_source] = space_type_source
    building[:number_of_stories] = number_of_stories
    building[:number_of_stories_source] = number_of_stories_source
    building[:number_of_stories_above_ground] = number_of_stories_above_ground
    building[:number_of_stories_above_ground_source] = number_of_stories_above_ground_source
    building[:number_of_stories_below_ground] = number_of_stories_below_ground
    building[:number_of_stories_below_ground_source] = number_of_stories_below_ground_source
    building[:number_of_residential_units] = number_of_residential_units
    building[:number_of_residential_units_source] = number_of_residential_units_source
    building[:year_built] = year_built
    building[:year_built_source] = year_built_source
    building[:structure_type] = structure_type
    building[:structure_type_source] = structure_type_source
    building[:structure_condition] = structure_condition
    building[:structure_condition_source] = structure_condition_source
    building[:average_roof_height] = average_roof_height
    building[:average_roof_height_source] = average_roof_height_source
    building[:maximum_roof_height] = maximum_roof_height
    building[:maximum_roof_height_source] = maximum_roof_height_source
    building[:minimum_roof_height] = minimum_roof_height
    building[:minimum_roof_height_source] = minimum_roof_height_source
    building[:surface_elevation] = surface_elevation
    building[:surface_elevation_source] = surface_elevation_source
    building[:roof_elevation] = roof_elevation
    building[:roof_elevation_source] = roof_elevation_source
    building[:roof_type] = roof_type
    building[:roof_type_source] = roof_type_source
    building[:floor_area] = floor_area
    building[:floor_area_source] = floor_area_source
    building[:intersecting_building_ids] = intersecting_building_ids
    building[:surrounding_building_ids] = surrounding_building_ids
    building[:footprint] = footprint
    building[:stories] = stories
    
    building.each {|key,value| building.delete(key) if value.nil? } 

    return building
  end
end

all_points = nil
File.open(points_csv, 'r') do |file|
  csv = CSV.new(file, :headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil])
  all_points = csv.to_a.map {|row| row.to_hash }
end

city_json = {}
city_json[:version] = "0.1"
city_json[:region] = {}
city_json[:taxlots] = []
city_json[:buildings] = []

File.open(buildings_csv, 'r') do |file|
  csv = CSV.new(file, :headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil])
  rows = csv.to_a.map {|row| row.to_hash }
  
  rows.each do |row|
    if !row[:taxlot_id].nil?
      taxlot = city_json[:taxlots].find {|t| t[:id] == row[:taxlot_id]}
      if taxlot.nil?
        taxlot = Taxlot.new(row, all_points)
        city_json[:taxlots] << taxlot.to_hash
      end
    end
    
    if !row[:bldg_fid].nil? && !row[:bldg_id].nil?
      building = city_json[:buildings].find {|b| b[:id] == row[:bldg_fid]}
      if building.nil?
        building = Building.new(row, all_points)
        city_json[:buildings] << building.to_hash
      end
    end
  end
end

max_wgs_84_x = nil
min_wgs_84_x = nil
max_wgs_84_y = nil
min_wgs_84_y = nil
city_json[:buildings].each do |building|
  building[:footprint][:polygons].each do |polygon|
    next if polygon[:coordinate_system] != "WGS 84"
      
    polygon[:points].each do |p|
      max_wgs_84_x = p[:x] if max_wgs_84_x.nil? || p[:x] > max_wgs_84_x
      min_wgs_84_x = p[:x] if min_wgs_84_x.nil? || p[:x] < min_wgs_84_x
      max_wgs_84_y = p[:y] if max_wgs_84_y.nil? || p[:y] > max_wgs_84_y
      min_wgs_84_y = p[:y] if min_wgs_84_y.nil? || p[:y] < min_wgs_84_y
    end
  end
end
mean_wgs_84_x = (max_wgs_84_x + min_wgs_84_x)/2.0
mean_wgs_84_y = (max_wgs_84_y + min_wgs_84_y)/2.0
wgs_84_region_pts = []
wgs_84_region_pts << {:x=>min_wgs_84_x, :y=>min_wgs_84_y}
wgs_84_region_pts << {:x=>min_wgs_84_x, :y=>max_wgs_84_y}
wgs_84_region_pts << {:x=>max_wgs_84_x, :y=>max_wgs_84_y}
wgs_84_region_pts << {:x=>max_wgs_84_x, :y=>min_wgs_84_y}

city_json[:region][:wgs_84_centroid] = {:x=>mean_wgs_84_x, :y=>mean_wgs_84_y}
city_json[:region][:polygon] = {:coordinate_system=>"WGS 84", :points=>wgs_84_region_pts, :holes=>[]}

puts "writing file out_json = #{out_json}"

File.open(out_json,"w") do |f|
  f << JSON.pretty_generate(city_json)
end