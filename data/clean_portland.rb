require 'rubygems'
require 'json-schema'
require_relative 'clean_common.rb'

def infer_geometry(data)
   # ensure that number_of_stories, number_of_stories_above_ground, number_of_stories_below_ground, surface_elevation, roof_elevation, and floor_area are set
    
  assumed_floor_to_floor_height = 3.65 # 12 ft
  
  zoning = data['zoning']
  number_of_stories = data['number_of_stories']
  surface_elevation = data['surface_elevation']
  roof_elevation = data['roof_elevation']
  average_roof_height = data['average_roof_height']
  minimum_roof_height = data['minimum_roof_height']
  maximum_roof_height = data['maximum_roof_height']
  floor_area = data['floor_area']
  footprint_area = data['footprint_area']
  
  height = nil
  num_floors_height = nil
  if roof_elevation && surface_elevation
    height = roof_elevation - surface_elevation
    num_floors_height = height / assumed_floor_to_floor_height
  elsif average_roof_height
    height = average_roof_height
    num_floors_height = height / assumed_floor_to_floor_height      
  end
  
  num_floors_area = nil
  if floor_area && footprint_area
    num_floors_area = floor_area / footprint_area
  end
  
  if number_of_stories.nil?
    if num_floors_height && num_floors_area
      number_of_stories = num_floors_area.round # prefer the area based weighting as height based metric does not include basements
    elsif num_floors_height
      number_of_stories = num_floors_height.round
    elsif num_floors_area
      number_of_stories = num_floors_area.round
    else
      raise "Insufficient height information"
    end
    data['number_of_stories_source'] = "Inferred"
  else
    data['number_of_stories_source'] = "Assessor"
  end
  
  # check that our resulting floor area is not too much larger than the reported area
  if footprint_area && floor_area
    resulting_area = footprint_area * number_of_stories
    
    # too high, reduce number of stories
    if resulting_area > 1.2 * floor_area
      new_result = [1, number_of_stories - 1].max
      new_resulting_area = footprint_area * new_result
      if (floor_area-new_resulting_area).abs < (floor_area-resulting_area).abs
        if data['number_of_stories_source'] == "Inferred"
          number_of_stories = new_result
          data['number_of_stories_source'] = "Inferred"
        end
      end
    elsif resulting_area < 0.8 * floor_area
      new_result = number_of_stories + 1
      new_resulting_area = footprint_area * new_result
      if (floor_area-new_resulting_area).abs < (floor_area-resulting_area).abs
        if data['number_of_stories_source'] == "Inferred"
          number_of_stories = new_result
          data['number_of_stories_source'] = "Inferred"
        end
      end
    end
  end

  # now try to figure out number of above and below ground surfaces
  if roof_elevation && surface_elevation && number_of_stories > 1
    floor_to_floor_height_no_basement = (roof_elevation - surface_elevation) / number_of_stories
    floor_to_floor_height_with_basement = (roof_elevation - surface_elevation) / (number_of_stories - 1)
    if (floor_to_floor_height_no_basement - assumed_floor_to_floor_height).abs < (floor_to_floor_height_with_basement - assumed_floor_to_floor_height).abs
      data['number_of_stories_above_ground'] = number_of_stories
      data['number_of_stories_above_ground_source'] = "Inferred"
      data['number_of_stories_below_ground'] = 0
      data['number_of_stories_below_ground_source'] = "Inferred"
    else
      data['number_of_stories_above_ground'] = number_of_stories-1
      data['number_of_stories_above_ground_source'] = "Inferred"
      data['number_of_stories_below_ground'] = 1
      data['number_of_stories_below_ground_source'] = "Inferred"
    end
  else
    data['number_of_stories_above_ground'] = number_of_stories
    data['number_of_stories_above_ground_source'] = "Inferred"
    data['number_of_stories_below_ground'] = 0
    data['number_of_stories_below_ground_source'] = "Inferred"
  end
  
end

def infer_space_type(data)
  # ensure that space_type is set
  
  space_type = data['space_type']
  bldg_use = data['bldg_use']
  zoning = data['zoning']
  floor_area = data['floor_area']
  number_of_residential_units = data['number_of_residential_units']
  
  if zoning
  end
  
  if space_type.nil? && bldg_use.nil?

    if zoning.nil? 
      if floor_area > 300 
        bldg_use = "Commercial Office"
      else
        bldg_use = "Single Family Residential"
      end
    elsif /R/.match(zone)
      if floor_area > 300 
        bldg_use = "Multi Family Residential"
      else
        bldg_use = "Single Family Residential"
      end
    else
      bldg_use = "Commercial Office"
    end
  end
  
  if bldg_use == "Multi Family Residential"
    if number_of_residential_units
      if number_of_residential_units <= 4
        space_type= "Multifamily (2 to 4 units)"
      else
        space_type= "Multifamily (5 or more units)"
      end
    else
      if floor_area > 800
        space_type= "Multifamily (5 or more units)"
      else
        space_type= "Multifamily (2 to 4 units)"
      end
    end
  elsif bldg_use == "Single Family Residential"
    space_type= "Single-Family"
  elsif bldg_use == "Commercial Grocery"
    space_type = "Food sales"
  elsif bldg_use == "Commercial Hotel"
    space_type = "Lodging"
  elsif bldg_use == "Commercial Office"
    space_type = "Office"
  elsif bldg_use == "Commercial Restaurant"
    space_type = "Food service"
  elsif bldg_use == "Commercial Retail"
    space_type = "Retail other than mall"
  elsif bldg_use == "Industrial"   
    space_type = "Nonrefrigerated warehouse"
  elsif bldg_use == "Institutional"    
    space_type = "Office"      
  elsif bldg_use == "Institutional Religious"    
    space_type = "Religious worship"
  elsif bldg_use == "Parking"    
    space_type = "Other"
  elsif bldg_use == "Vacant"    
    space_type = "Vacant"
  else
    raise "Unknown bldg_use '#{bldg_use}'"
  end

end





clean_buildings('portland')