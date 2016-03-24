require 'rubygems'
require 'json-schema'
require_relative 'clean_common.rb'

#  Data from:
#    Marc Costa

class LACleaner < Cleaner

  def name()
    return "LA"
  end
  
  # return a string that will match files to clean in glob
  def file_pattern()
    return "la*_buildings_*.geojson"
  end
  
  def infer_geometry(data)

    total_height = nil

    average_roof_height = data['average_roof_height']
    average_roof_height_source = data['average_roof_height_source']
    floor_area = data['floor_area']
    floor_area_source = data['floor_area_source']
    footprint_area = data['footprint_area']
    footprint_area_source = data['footprint_area_source']    
    maximum_roof_height = data['maximum_roof_height']
    maximum_roof_height_source = data['maximum_roof_height_source']
    minimum_roof_height = data['minimum_roof_height']
    minimum_roof_height_source = data['minimum_roof_height_source']
    number_of_stories = data['number_of_stories']
    number_of_stories_source = data['number_of_stories_source']
    number_of_stories_above_ground = data['number_of_stories_above_ground']
    number_of_stories_above_ground_source = data['number_of_stories_above_ground_source']
    number_of_stories_below_ground = data['number_of_stories_below_ground']
    number_of_stories_below_ground_source = data['number_of_stories_below_ground_source']
    roof_elevation = data['roof_elevation']
    roof_elevation_source = data['roof_elevation_source']
    roof_type = data['roof_type']
    roof_type_source = data['roof_type_source']
    surface_elevation = data['surface_elevation']
    surface_elevation_source = data['surface_elevation_source']
    zoning = data['zoning']
    
    # todo: different assumed height for first floor of mixed use?
    
    assumed_floor_to_floor_height = 3.65 # 12 ft
    if zoning == 'Residential'
      assumed_floor_to_floor_height = 3.048 # 10 ft
    end
    
    if number_of_stories == 0
      number_of_stories = nil
    end
    
    if surface_elevation && roof_elevation
      total_height = roof_elevation.to_f - surface_elevation.to_f
    elsif maximum_roof_height
      total_height = maximum_roof_height.to_f
    end
    
    # DLM: maximum and minimum roof height do not appear to be reliable 
    #if roof_type.nil? && maximum_roof_height && minimum_roof_height
    #  if maximum_roof_height < minimum_roof_height + 0.5
    #    roof_type = "Flat"
    #    roof_type_source = "Inferred"
    #  else
    #    roof_type = "Pitched"
    #    roof_type_source = "Inferred"
    #  end
    #end  
      

    if number_of_stories.nil?
      
      num_floors_height = nil
      if total_height
        num_floors_height = total_height / assumed_floor_to_floor_height  
      end
     
      num_floors_area = nil
      if floor_area && footprint_area
        num_floors_area = floor_area.to_f / footprint_area.to_f
      end
    
      if num_floors_height && num_floors_area
        number_of_stories = num_floors_area.round # prefer the area based weighting as height based metric does not include basements
        number_of_stories_source = "Inferred"
      elsif num_floors_height
        number_of_stories = num_floors_height.round
        number_of_stories_source = "Inferred"
      elsif num_floors_area
        number_of_stories = num_floors_area.round
        number_of_stories_source = "Inferred"
      else
        number_of_stories = 1
        number_of_stories_source = "Inferred"
      end
    end
    
    if number_of_stories.nil?
      number_of_stories = 1
      number_of_stories_source = "Inferred"
    end
    
    if total_height.nil?
      total_height = number_of_stories * assumed_floor_to_floor_height
    end
    
    # DLM: NA for LA
    # check that our resulting floor area is not too much larger than the reported area
    #if footprint_area && floor_area
    #  resulting_area = footprint_area * number_of_stories
    #  if resulting_area > 1.2 * floor_area
    #    new_result = [1, number_of_stories - 1].max
    #    new_resulting_area = footprint_area * new_result
    #    if (floor_area-new_resulting_area).abs < (floor_area-resulting_area).abs
    #      number_of_stories = new_result
    #      number_of_stories_source = "Inferred"
    #      
    #      total_height = number_of_stories * assumed_floor_to_floor_height
    #    end
    #  end
    #end

    # DLM: NA for LA
    # now try to figure out number of above and below ground surfaces    
    #if number_of_stories > 1
    #  floor_to_floor_height_no_basement = total_height / number_of_stories
    #  floor_to_floor_height_with_basement = total_height / (number_of_stories - 1)
    #  if (floor_to_floor_height_no_basement - assumed_floor_to_floor_height).abs < (floor_to_floor_height_with_basement - assumed_floor_to_floor_height).abs
    #    number_of_stories_above_ground = number_of_stories
    #    number_of_stories_above_ground_source = "Inferred"
    #    number_of_stories_below_ground = 0
    #    number_of_stories_below_ground_source = "Inferred"
    #  else
    #    number_of_stories_above_ground = number_of_stories-1
    #    number_of_stories_above_ground_source = "Inferred"
    #    number_of_stories_below_ground = 1
    #    number_of_stories_below_ground_source = "Inferred"
    #  end
    #else
      number_of_stories_above_ground = number_of_stories
      number_of_stories_above_ground_source = "Inferred"
      number_of_stories_below_ground = 0
      number_of_stories_below_ground_source = "Inferred"
    #end
    
    # DLM: NA for LA
    #if roof_elevation.nil? && surface_elevation.nil?
    #  surface_elevation = 0
    #  surface_elevation_source = "Inferred"
    #  roof_elevation = number_of_stories_above_ground * assumed_floor_to_floor_height
    #  roof_elevation_source = "Inferred"
    #elsif roof_elevation.nil? 
    #  roof_elevation = surface_elevation + number_of_stories_above_ground * assumed_floor_to_floor_height
    #  roof_elevation_source = "Inferred"
    #elsif surface_elevation.nil?
    #  surface_elevation = roof_elevation - number_of_stories_above_ground * assumed_floor_to_floor_height
    #  surface_elevation_source = "Inferred"
    #end
    
    #if floor_area.nil?
    #  floor_area = footprint_area * number_of_stories
    #  floor_area_source = "Inferred" 
    #end
    
     data['average_roof_height'] = average_roof_height
     data['average_roof_height_source'] = average_roof_height_source
     data['floor_area'] = floor_area
     data['floor_area_source'] = floor_area_source
     data['footprint_area'] = footprint_area
     data['footprint_area_source'] = footprint_area_source    
     data['maximum_roof_height'] = maximum_roof_height
     data['maximum_roof_height_source'] = maximum_roof_height_source
     data['minimum_roof_height'] = minimum_roof_height
     data['minimum_roof_height_source'] = minimum_roof_height_source
     data['number_of_stories'] = number_of_stories
     data['number_of_stories_source'] = number_of_stories_source
     data['number_of_stories_above_ground'] = number_of_stories_above_ground
     data['number_of_stories_above_ground_source'] = number_of_stories_above_ground_source
     data['number_of_stories_below_ground'] = number_of_stories_below_ground
     data['number_of_stories_below_ground_source'] = number_of_stories_below_ground_source
     data['roof_elevation'] = roof_elevation
     data['roof_elevation_source'] = roof_elevation_source
     data['roof_type'] = roof_type
     data['roof_type_source'] = roof_type_source
     data['surface_elevation'] = surface_elevation
     data['surface_elevation_source'] = surface_elevation_source

  end

  def infer_space_type(data)

    zoning = data['zoning']
    zoning_source = data['zoning_source']
    floor_area = data['floor_area']
    floor_area_source = data['floor_area_source']
    number_of_stories = data['number_of_stories']
    number_of_stories_source = data['number_of_stories_source']
    space_type = data['space_type']
    space_type_source = data['space_type_source']
    
    if zoning.nil?
      zoning = "Vacant"
      zoning_source = "Inferred"
    end
    
    if space_type.nil?
      if zoning == "Vacant"
        space_type = "Vacant"
        space_type_source = "Inferred"
      elsif zoning == "Mixed"
        if floor_area < 300
          space_type = "Single-Family"
          space_type_source = "Inferred"
        elsif floor_area < 500
          space_type = "Multifamily (2 to 4 units)"
          space_type_source = "Inferred"
        else
          space_type = "Multifamily (5 or more units)"
          space_type_source = "Inferred"
        end
      elsif zoning == "Residential"
        if floor_area < 300
          space_type = "Single-Family"
          space_type_source = "Inferred"
        elsif floor_area < 500
          space_type = "Multifamily (2 to 4 units)"
          space_type_source = "Inferred"
        else
          space_type = "Multifamily (5 or more units)"
          space_type_source = "Inferred"
        end
      elsif zoning == "Commercial"
        space_type = "Office"
        space_type_source = "Inferred"
      elsif zoning == "OpenSpace"
        space_type = "Vacant"        
        space_type_source = "Inferred"
      end
    end
    
    data['zoning'] = zoning
    data['zoning_source'] = zoning_source
    data['space_type'] = space_type
    data['space_type_source'] = space_type_source
    
  end
  
  def clean_building(data, schema)

    if data['BLD_ID']
      data['source_id'] = data['BLD_ID'].to_s
    end
    
    if data['SOURCE']
      data['source_name'] = data['SOURCE'].to_s
    end
    
    if data['ELEV']
      data['surface_elevation'] = data['ELEV'].to_f
      if data['HEIGHT']
        data['roof_elevation'] = data['surface_elevation'] + data['HEIGHT'].to_f
      end
    end
    
    # make up
    data['zoning'] = "Commercial"
    data['intersecting_building_source_ids'] = []
    data['floor_area'] = 100
    
    infer_geometry(data)
    infer_space_type(data) 
    
    super(data, schema)
  end

  def clean_taxlot(data, schema)

    if data['type'] == 'taxlot'
      data['type'] = 'Taxlot'
    end
    
    if data['source_id'].class == Fixnum
      data['source_id'] = data['source_id'].to_s
    end
    
    if data['census_tract'].class == Fixnum
      data['census_tract'] = data['census_tract'].to_s
    end 

    if data['zoning'] == "Auto Dealer"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Auto Service"      
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Broadcast Facility"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Carwash"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Cemetary"    
      data['zoning'] = "Commercial"   
    elsif data['zoning'] == "Church"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Dry Cleaning"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Entertainment"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Factory"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Fire Station"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Financial Building"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Food Processing"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Gas Station"    
      data['zoning'] = "Commercial"   
    elsif data['zoning'] == "Greenhouse"    
      data['zoning'] = "Commercial"   
    elsif data['zoning'] == "Health Spa"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Laundromat"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Library"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Lodging"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Manufacturing"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Medical Services"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Mortuary"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Museum"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Meeting Hall"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Mini-Storage"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Office"      
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Other Commercial/Retail"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Other Industrial"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Preschool"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Printing"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Restaurant"      
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Retail"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "School"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "TCU"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Theater"    
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "Warehouse"      
      data['zoning'] = "Commercial"
      
    elsif data['zoning'] == "Mixed-Use"      
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "Mixed-Use w/ Residential"      
      data['zoning'] = "Mixed"

    elsif data['zoning'] == "Apartment"      
      data['zoning'] = "Residential"
    elsif data['zoning'] == "Condominium"      
      data['zoning'] = "Residential"
    elsif data['zoning'] == "Group Quarters"      
      data['zoning'] = "Residential"
    elsif data['zoning'] == "Mobile Home/Trailer Park"      
      data['zoning'] = "Residential"
    elsif data['zoning'] == "Rowhouse/Townhome"    
      data['zoning'] = "Residential"
    elsif data['zoning'] == "Senior Housing"      
      data['zoning'] = "Residential"
    elsif data['zoning'] == "Single Family"      
      data['zoning'] = "Residential"
    elsif data['zoning'] == "Single Family Conversion"      
      data['zoning'] = "Residential"
      
    elsif data['zoning'] == "Agriculture"      
      data['zoning'] = "Vacant"
     elsif data['zoning'] == "Golf Course"      
      data['zoning'] = "Vacant"   
    elsif data['zoning'] == "Open Space"      
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "Other/Unknown"      
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "Park"      
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "Parking Garage"      
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "Recreation"      
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "ROW/Road"      
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "Surface Parking"    
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "Surface Water"    
      data['zoning'] = "Vacant"
     elsif data['zoning'] == "Urban Garden"      
      data['zoning'] = "Vacant"   
     elsif data['zoning'] == "Vacant"      
      data['zoning'] = "Vacant"   
    end   
    
    if data['zoning_source'] == "NREL_GDS"      
      data['zoning_source'] = nil
    end  
    
    super(data, schema)
  end
  
  def clean_region(data, schema)
  
    if data['type'] == 'region'
      data['type'] = 'Region'
    end
    
    if data['source_id'].class == Fixnum
      data['source_id'] = data['source_id'].to_s
    end
    
    super(data, schema)
  end

end

cleaner = LACleaner.new 
cleaner.clean_originals
cleaner.gather_stats
cleaner.clean
cleaner.write_csvs