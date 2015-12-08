require 'csv'
require 'fileutils'
require 'json'

# converts building and points csv files to a JSON format

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


class Building

  def initialize(row, all_points)
    @row = row
    @all_points = all_points
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
    @row[:bldg_numb].nil? ? nil : @row[:bldg_numb]
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
    #@row[:bldg_type]
    return nil
  end
  
  def space_type_source
    #@row[:bldg_type]
    return nil
  end
  
  def number_of_stories
    @row[:num_story].nil? ? nil : @row[:num_story]
  end
  
  def number_of_stories_above_ground
    return nil
  end
  
  def number_of_stories_below_ground
    return nil
  end
  
  def number_of_stories_source
    return nil
  end
  
  def number_of_residential_units
    @row[:units_res].nil? ? nil : @row[:units_res]
  end
  
  def number_of_residential_units_source
    return nil
  end
  
  def year_built
    @row[:year_built].nil? ? nil : @row[:year_built]
  end  
  
  def year_built_source
    return nil
  end  
  
  def structure_type
    @row[:struc_type].nil? ? nil : @row[:struc_type].to_s
  end  
  
  def structure_type_source
    return nil
  end
  
  def structure_condition
    @row[:struc_cond].nil? ? nil : @row[:struc_cond].to_s
  end
  
  def average_roof_height
    @row[:avg_height_m].nil? ? nil : @row[:avg_height_m]
  end
  
  def maximum_roof_height
    @row[:max_height_m].nil? ? nil : @row[:max_height_m]
  end 
  
  def minimum_roof_height
    @row[:min_height_m].nil? ? nil : @row[:min_height_m]
  end
  
  def surface_elevation
    @row[:surf_elev_m].nil? ? nil : @row[:surf_elev_m]
  end
  
  def roof_elevation
    @row[:roof_elev_m].nil? ? nil : @row[:roof_elev_m]
  end
  
  def height_source
    return nil
  end  
  
  def roof_type
    result = @row[:roof_type].nil? ? nil : @row[:roof_type].to_s
    if result == "Asphalt Shingle"
      result = nil
    elsif result == "Metal"
      result = nil
    elsif result == "Multi-level"
      result = "Multi-level Flat"
    end
  end  
  
  def roof_type_source
    return nil
  end  
  
  def floor_area
    @row[:bldg_area_m2].nil? ? nil : @row[:bldg_area_m2]
  end  
  
  def floor_area_source
    return nil
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
    return []
  end  
  
  def footprint
    this_id = @row[:bldg_fid]
    points = @all_points.select{|p| p[:bldg_fid] == this_id}
    
    multi_part_plygn_indices = points.collect {|p| p[:multi_part_plygn_index] }.uniq
    plygn_indices = points.collect {|p| p[:plygn_index] }.uniq
    
    footprint = {}
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
  
  def stories
    return nil
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
    building[:number_of_stories_above_ground] = number_of_stories_above_ground
    building[:number_of_stories_below_ground] = number_of_stories_below_ground
    building[:number_of_stories_source] = number_of_stories_source
    building[:number_of_residential_units] = number_of_residential_units
    building[:number_of_residential_units_source] = number_of_residential_units_source
    building[:year_built] = year_built
    building[:year_built_source] = year_built_source
    building[:structure_type] = structure_type
    building[:structure_type_source] = structure_type_source
    building[:structure_condition] = structure_condition
    building[:average_roof_height] = average_roof_height
    building[:maximum_roof_height] = maximum_roof_height
    building[:minimum_roof_height] = minimum_roof_height
    building[:surface_elevation] = surface_elevation
    building[:roof_elevation] = roof_elevation
    building[:height_source] = height_source
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
    
    building = city_json[:buildings].find {|b| b[:id] == row[:bldg_fid]}
    if building.nil?
      building = Building.new(row, all_points)
      city_json[:buildings] << building.to_hash
    end
  end
end

#File.open(points_csv, 'r') do |file|
#  csv = CSV.new(file, :headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil])
#  rows = csv.to_a.map {|row| row.to_hash }
#  rows.each do |row|
#    if buildings[row[:bldg_fid]]
#      buildings[row[:bldg_fid]][:points] << row
#    else
#      puts "Can't find building #{row[:bldg_fid]}"
#    end
#  end
#end

#buildings.each_value do |building|
#  building[:points].sort! do |x, y| 
#    result = x[:multi_part_plygn_index].to_i <=> y[:multi_part_plygn_index].to_i
#    result = x[:plygn_index].to_i <=> y[:plygn_index].to_i if result == 0
#    result = x[:point_order].to_i <=> y[:point_order].to_i if result == 0
#    result
#  end
#end

puts "writing file out_json = #{out_json}"

File.open(out_json,"w") do |f|
  f << JSON.pretty_generate(city_json)
end