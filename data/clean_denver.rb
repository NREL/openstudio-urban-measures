require 'rubygems'
require 'json-schema'
require_relative 'clean_common.rb'

def infer_geometry(data)
   # ensure that number_of_stories, number_of_stories_above_ground, number_of_stories_below_ground, surface_elevation, roof_elevation, and floor_area are set
    
  assumed_floor_to_floor_height = 3.65 # 12 ft
  
  if data['number_of_stories'] == 0
    data['number_of_stories'] = nil
  end
  
  zoning = data['zoning']
  number_of_stories = data['number_of_stories']
  surface_elevation = data['surface_elevation']
  roof_elevation = data['roof_elevation']
  floor_area = data['floor_area']
  footprint_area = data['footprint_area']
  
  # if number_of_stories.nil?

  # @last_number_of_stories_source = "Inferred"

  # num_floors_height = nil
  # if @object[:roof_elev_m] && @object[:surf_elev_m]
    # height = @object[:roof_elev_m].to_f - @object[:surf_elev_m].to_f
    # num_floors_height = height / @assumed_floor_to_floor_height
  # elsif @object[:avg_height_m] 
    # height = @object[:avg_height_m].to_f
    # num_floors_height = height / @assumed_floor_to_floor_height      
  # elsif @object[:min_height_m] 
    # height = @object[:min_height_m].to_f
    # num_floors_height = height / @assumed_floor_to_floor_height      
  # elsif @object[:max_height_m]  
    # height = @object[:max_height_m].to_f
    # num_floors_height = height / @assumed_floor_to_floor_height 
  # end
  
  # num_floors_area = nil
  # if @object[:bldg_area_m2] && @object[:bldg_footprint_m2]
    # num_floors_area = @object[:bldg_area_m2].to_f / @object[:bldg_footprint_m2].to_f
  # end
  
  # if num_floors_height && num_floors_area
    # result = num_floors_area.round # prefer the area based weighting as height based metric does not include basements
  # elsif num_floors_height
    # result = num_floors_height.round
  # elsif num_floors_area
    # result = num_floors_area.round
  # else
    # result = 1
    # puts "No number_of_stories information for building #{source_id}"
  # end

  # else
    # result = result.to_i
    # @last_number_of_stories_source = "Assessor"
  # end

  # # check that our resulting floor area is not too much larger than the reported area
  # if @object[:bldg_footprint_m2] && @object[:bldg_area_m2]
    # resulting_area = @object[:bldg_footprint_m2] * result
    # if resulting_area > 1.2 * @object[:bldg_area_m2]
      # new_result = [1, result - 1].max
      # new_resulting_area = @object[:bldg_footprint_m2] * new_result
      # if (@object[:bldg_area_m2]-new_resulting_area).abs < (@object[:bldg_area_m2]-resulting_area).abs
        # result = new_result
        # @last_number_of_stories_source = "Inferred"
      # end
    # end
  # end

  # # now try to figure out number of above and below ground surfaces
  # if @object[:roof_elev_m] && @object[:surf_elev_m] && result > 1
    # floor_to_floor_height_no_basement = (@object[:roof_elev_m] - @object[:surf_elev_m]) / result
    # floor_to_floor_height_with_basement = (@object[:roof_elev_m] - @object[:surf_elev_m]) / (result - 1)
    # if (floor_to_floor_height_no_basement - @assumed_floor_to_floor_height).abs < (floor_to_floor_height_with_basement - @assumed_floor_to_floor_height).abs
      # @last_number_of_stories_above_ground = result
      # @last_number_of_stories_above_ground_source = "Inferred"
      # @last_number_of_stories_below_ground = 0
      # @last_number_of_stories_below_ground_source = "Inferred"
    # else
      # @last_number_of_stories_above_ground = result-1
      # @last_number_of_stories_above_ground_source = "Inferred"
      # @last_number_of_stories_below_ground = 1
      # @last_number_of_stories_below_ground_source = "Inferred"
    # end
  # else
    # @last_number_of_stories_above_ground = result
    # @last_number_of_stories_above_ground_source = "Inferred"
    # @last_number_of_stories_below_ground = 0
    # @last_number_of_stories_below_ground_source = "Inferred"
  # end

end

def infer_space_type(data)
  # ensure that space_type is set
  
  zoning = data['zoning']
  floor_area = data['floor_area']
  space_type = data['space_type']
  
end


clean_buildings('denver')
clean_taxlots('denver')