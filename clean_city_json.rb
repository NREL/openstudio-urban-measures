require 'fileutils'
require 'json'

# converts exported geojson files to standard JSON format
# ruby clean_city_json.rb e:\insight-center\portland\json_output\json_output\san_francisco_bldg_footprints_4326.json city.json

input_json = ARGV[0]
out_json = ARGV[1]

if !File.exists?(input_json)
  raise "input_json = #{input_json} does not exist"
end

# this class can be extended per city if needed
class Taxlot
  def initialize(object)
    @object = object
    @last_zoning_source = nil
  end
  
  def source_id
    @object[:lot_fid].nil? ? nil : @object[:lot_fid].to_s
  end
  
  def zoning
    result = @object[:landuse]
    if result == "MIXRES"
      result = "Mixed"
      @last_zoning_source = "Assessor"
    elsif result == "MIXED"
      result = "Mixed"      
      @last_zoning_source = "Assessor"
    elsif result == "RESIDENT"
      result = "Residential"
      @last_zoning_source = "Assessor"
    elsif result == "RETAIL/ENT"
      result = "Commercial"
      @last_zoning_source = "Assessor"
    elsif result == "MIPS"
      result = "Commercial" 
      @last_zoning_source = "Assessor"
    elsif result == "VACANT"
      result = "Vacant"       
      @last_zoning_source = "Assessor"
    elsif result == "VISITOR"
      result = "Commercial"     
      @last_zoning_source = "Assessor"      
    elsif result == "OpenSpace"
      result = "OpenSpace"      
      @last_zoning_source = "Assessor"
    elsif result == "CIE"
      result = "Commercial"    
      @last_zoning_source = "Assessor"
    elsif result == "MISSING DATA"
      result = nil       
    end
    
    return result
  end  
  
  def zoning_source
    @last_zoning_source
  end
  
  def to_hash
    taxlot = {}
    taxlot[:source_id] = source_id
    taxlot[:zoning] = zoning
    taxlot[:zoning_source] = zoning_source

    # "mapblklot": "0024022", this is really more of a source id right?
    
    taxlot.each {|key,value| taxlot.delete(key) if value.nil? } 
    
    return taxlot
  end
end

# this class can be extended per city if needed
class Building

  def initialize(object)
    @object = object
    @last_zoning_source = nil
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
  
  def source_id
    @object[:bldg_fid].nil? ? nil : @object[:bldg_fid].to_s
  end
  
  def taxlot_id
    @object[:taxlot_id].nil? ? nil : @object[:taxlot_id].to_s
  end  
  
  def building_number
    @object[:bldg_numb].nil? ? nil : @object[:bldg_numb].to_i
  end  
  
  def name
    @object[:bldg_name].nil? ? nil : @object[:bldg_name].to_s
  end  
  
  def address
    @object[:bldg_addr].nil? ? nil : @object[:bldg_addr].to_s
  end  
  
  def footprint_area
    @object[:bldg_footprint_m2].nil? ? nil : @object[:bldg_footprint_m2].to_f
  end
  
  def footprint_area_source
    return nil
  end
  
  def footprint_perimeter
    @object[:bldg_perimeter_m].nil? ? nil : @object[:bldg_perimeter_m].to_f
  end
  
  def footprint_perimeter_source  
    return nil
  end
  
  def zoning
    result = @object[:zone]
    if result == "MIXRES"
      result = "Mixed"
      @last_zoning_source = "Assessor"
    elsif result == "MIXED"
      result = "Mixed"      
      @last_zoning_source = "Assessor"
    elsif result == "RESIDENT"
      result = "Residential"
      @last_zoning_source = "Assessor"
    elsif result == "RETAIL/ENT"
      result = "Commercial"
      @last_zoning_source = "Assessor"
    elsif result == "MIPS"
      result = "Commercial" 
      @last_zoning_source = "Assessor"
    elsif result == "VACANT"
      result = "Vacant"       
      @last_zoning_source = "Assessor"
    elsif result == "VISITOR"
      result = "Commercial"     
      @last_zoning_source = "Assessor"      
    elsif result == "OpenSpace"
      result = "OpenSpace"      
      @last_zoning_source = "Assessor"
    elsif result == "CIE"
      result = "Commercial"    
      @last_zoning_source = "Assessor"
    elsif result == "MISSING DATA"
      result = nil       
    end
    
    return result
  end  
  
  def zoning_source
    @last_zoning_source
  end
  
  def building_status
    @object[:bldg_stat].nil? ? nil : @object[:bldg_stat].to_s
  end  
  
  def building_status_source
    nil
  end  
  
  def space_type
    space_use = @object[:bldg_use]

    if space_use.nil?
      @last_space_type_source = "Inferred"
      
      zone = @object[:zone]
      if zone.nil?
        if @object[:bldg_footprint_m2].nil?
          space_use = "Single Family Residential"
        elsif @object[:bldg_footprint_m2] > 300 
          space_use = "Commercial Office"
        else
          space_use = "Single Family Residential"
        end
      elsif /R/.match(zone)
        if @object[:bldg_footprint_m2].nil?
          space_use = "Single Family Residential"
        elsif @object[:bldg_footprint_m2] > 300 
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
      if @object[:units_res]
        if @object[:units_res].to_i <= 4
          cbecs_space_use= "Multifamily (2 to 4 units)"
        else
          cbecs_space_use= "Multifamily (5 or more units)"
        end
      else
        if @object[:bldg_footprint_m2] > 800
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
    result = @object[:num_story]
    
    if result.nil?
      @last_number_of_stories_source = "Inferred"
      
      num_floors_height = nil
      if @object[:roof_elev_m] && @object[:surf_elev_m]
        height = @object[:roof_elev_m].to_f - @object[:surf_elev_m].to_f
        num_floors_height = height / @assumed_floor_to_floor_height
      end
      
      num_floors_area = nil
      if @object[:bldg_area_m2] && @object[:bldg_footprint_m2]
        num_floors_area = @object[:bldg_area_m2].to_f / @object[:bldg_footprint_m2].to_f
      end
      
      if num_floors_height && num_floors_area
        result = num_floors_area.round # prefer the area based weighting as height based metric does not include basements
      elsif num_floors_height
        result = num_floors_height.round
      elsif num_floors_area
        result = num_floors_area.round
      else
        result = 1
        puts "No number_of_stories information for building #{source_id}"
      end

    else
      result = result.to_i
      @last_number_of_stories_source = "Assessor"
    end
    
    # check that our resulting floor area is not too much larger than the reported area
    if @object[:bldg_footprint_m2] && @object[:bldg_area_m2]
      resulting_area = @object[:bldg_footprint_m2] * result
      if resulting_area > 1.2 * @object[:bldg_area_m2]
        new_result = [1, result - 1].max
        new_resulting_area = @object[:bldg_footprint_m2] * new_result
        if (@object[:bldg_area_m2]-new_resulting_area).abs < (@object[:bldg_area_m2]-resulting_area).abs
          result = new_result
          @last_number_of_stories_source = "Inferred"
        end
      end
    end
    
    # now try to figure out number of above and below ground surfaces
    if @object[:roof_elev_m] && @object[:surf_elev_m] && result > 1
      floor_to_floor_height_no_basement = (@object[:roof_elev_m] - @object[:surf_elev_m]) / result
      floor_to_floor_height_with_basement = (@object[:roof_elev_m] - @object[:surf_elev_m]) / (result - 1)
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
    result = @object[:units_res]
    
    if result.nil?
      @last_number_of_residential_units_source = "Inferred"
      
      area = nil
      if @object[:bldg_area_m2]
        area = @object[:bldg_area_m2]
      elsif @object[:bldg_footprint_m2]
        area = @object[:bldg_footprint_m2]*number_of_stories
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
    @object[:year_built].nil? ? nil : @object[:year_built].to_i
  end  
  
  def year_built_source
    result = nil
    if !@object[:year_built].nil?
      result = "Assessor"
    end
    return result
  end  
  
  def structure_type
    @object[:struc_type].nil? ? nil : @object[:struc_type].to_s
  end  
  
  def structure_type_source
    result = nil
    if !@object[:struc_type].nil?
      result = "Assessor"
    end
    return result
  end
  
  def structure_condition
    @object[:struc_cond].nil? ? nil : @object[:struc_cond].to_s
  end
  
  def structure_condition_source
    result = nil
    if !@object[:struc_cond].nil?
      result = "Assessor"
    end
    return result
  end
  
  def average_roof_height
    @object[:avg_height_m].nil? ? nil : @object[:avg_height_m]
  end
  
  def average_roof_height_source
    result = nil
    if !@object[:avg_height_m].nil?
      result = "Measured"
    end
    return result
  end
  
  def maximum_roof_height
    @object[:max_height_m].nil? ? nil : @object[:max_height_m]
  end 
  
  def maximum_roof_height_source
    result = nil
    if !@object[:max_height_m].nil?
      result = "Measured"
    end
    return result
  end
  
  def minimum_roof_height
    @object[:min_height_m].nil? ? nil : @object[:min_height_m]
  end
  
  def minimum_roof_height_source
    result = nil
    if !@object[:min_height_m].nil?
      result = "Measured"
    end
    return result
  end
  
  def surface_elevation
    result = @object[:surf_elev_m]
    
    if result.nil?
      @last_roof_elevation_source = "Inferred"
      
      if @object[:roof_elev_m]
        result = @object[:roof_elev_m].to_f - number_of_stories*@assumed_floor_to_floor_height
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
    result = @object[:roof_elev_m]
    
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
    result = @object[:roof_type].nil? ? nil : @object[:roof_type].to_s
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
    if roof_type && !@object[:roof_type].nil?
      result = "Assessor"
    end
    return result
  end  
  
  def floor_area
    @object[:bldg_area_m2].nil? ? nil : @object[:bldg_area_m2]
  end  
  
  def floor_area_source
    result = nil
    if !@object[:bldg_area_m2].nil?
      result = "Assessor"
    end
    return result
  end  
  
  def intersecting_building_ids
    result = []
    if !@object[:intersecting_bldg_fid].nil? 
      if (md = /\[(.*)\]/.match(@object[:intersecting_bldg_fid].to_s))
        md[1].split(',').each do |id|
          result << id.to_s.strip
        end
      end
    end
    return result
  end  
  
  def surrounding_building_ids
    result = []
    if !@object[:surrounding_building_id].nil? 
      if (md = /\[(.*)\]/.match(@object[:surrounding_building_id].to_s))
        md[1].split(',').each do |id|
          result << id.to_s.strip
        end
      end
    end
    return result
  end  
  
  def window_to_wall_ratio
    return 0.4
  end
  
  def window_to_wall_ratio_source
    return nil
  end
  
  def stories 
    result = []
    st = space_type
    wwr = window_to_wall_ratio
    below_ground = number_of_stories_below_ground
    above_ground = number_of_stories_above_ground
    elevation = surface_elevation - @assumed_floor_to_floor_height*below_ground

    ((-below_ground+1)..above_ground).each do |story_number|
      name = "Bldg #{@object[:bldg_fid]} Story #{story_number}"
      result << {:name => name, :story_number => story_number, :floor_to_floor_height => @assumed_floor_to_floor_height, :elevation => elevation, :window_to_wall_ratio => wwr, :space_type => st}
      elevation += @assumed_floor_to_floor_height
    end
    
    return result
  end
  
  def to_hash
    building = {}
    building[:feature_type] = "Building"
    building[:source_id] = source_id
    building[:name] = name
    building[:address] = address
    building[:footprint_area] = footprint_area
    building[:footprint_area_source] = footprint_area_source
    building[:footprint_perimeter] = footprint_perimeter
    building[:footprint_perimeter_source] = footprint_perimeter_source    
    building[:zoning] = zoning
    building[:zoning_source] = zoning_source
    
    building[:taxlot_id] = taxlot_id
    building[:building_number] = building_number
    building[:building_status] = building_status
    building[:building_status_source] = building_status_source
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
    building[:window_to_wall_ratio] = window_to_wall_ratio
    building[:window_to_wall_ratio_source] = window_to_wall_ratio_source    
    building[:intersecting_building_ids] = intersecting_building_ids
    building[:surrounding_building_ids] = surrounding_building_ids
    building[:stories] = stories
    
    building.each {|key,value| building.delete(key) if value.nil? } 

    return building
  end
end

city_json = {}
File.open(input_json, 'r') do |file|
  json = JSON.parse(file.read, :symbolize_names => true)
  city_json[:crs] = json[:crs]
  city_json[:type] = json[:type]
  city_json[:features] = []
  
  json[:features].each do |feature|
    # figure out if this is a taxlot or a building
    if feature[:properties].has_key?(:landuse)
      taxlot = Taxlot.new(feature[:properties])
      feature[:properties] = taxlot.to_hash
    elsif feature[:properties].has_key?(:bldg_use)
      building = Building.new(feature[:properties])
      feature[:properties] = building.to_hash
    else
      puts "Unknown feature"
    end
    
    feature[:id] = feature[:properties][:source_id]
    
    city_json[:features] << feature
  end
  
end

puts "writing file out_json = #{out_json}"

File.open(out_json,"w") do |f|
  f << JSON.pretty_generate(city_json)
end