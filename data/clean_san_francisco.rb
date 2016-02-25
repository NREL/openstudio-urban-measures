require 'rubygems'
require 'json-schema'
require_relative 'clean_common.rb'

class SanFranciscoCleaner < Cleaner

  def name()
    return "San Francisco"
  end
  
  # return a string that will match files to clean in glob
  def file_pattern()
    return "US_CA_*.geojson"
  end
  
  def infer_geometry(data)
    errors = []  
      
    total_height = nil
    assumed_floor_to_floor_height = 3.65 # 12 ft

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
    surface_elevation = data['surface_elevation']
    surface_elevation_source = data['surface_elevation_source']
    
    if number_of_stories == 0
      number_of_stories = nil
    end
    
    if surface_elevation && roof_elevation
      total_height = roof_elevation.to_f - surface_elevation.to_f
    elsif average_roof_height
      total_height = average_roof_height.to_f
    elsif minimum_roof_height && maximum_roof_height
      total_height = (minimum_roof_height.to_f + maximum_roof_height.to_f) / 2.0
    end
    
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
      
      total_height = number_of_stories * assumed_floor_to_floor_height
    end
    
    # check that our resulting floor area is not too much larger than the reported area
    if footprint_area && floor_area
      resulting_area = footprint_area * number_of_stories
      if resulting_area > 1.2 * floor_area
        new_result = [1, number_of_stories - 1].max
        new_resulting_area = footprint_area * new_result
        if (floor_area-new_resulting_area).abs < (floor_area-resulting_area).abs
          number_of_stories = new_result
          number_of_stories_source = "Inferred"
          
          total_height = number_of_stories * assumed_floor_to_floor_height
        end
      end
    end

    # now try to figure out number of above and below ground surfaces    
    if number_of_stories > 1
      floor_to_floor_height_no_basement = total_height / number_of_stories
      floor_to_floor_height_with_basement = total_height / (number_of_stories - 1)
      if (floor_to_floor_height_no_basement - assumed_floor_to_floor_height).abs < (floor_to_floor_height_with_basement - assumed_floor_to_floor_height).abs
        number_of_stories_above_ground = number_of_stories
        number_of_stories_above_ground_source = "Inferred"
        number_of_stories_below_ground = 0
        number_of_stories_below_ground_source = "Inferred"
      else
        number_of_stories_above_ground = number_of_stories-1
        number_of_stories_above_ground_source = "Inferred"
        number_of_stories_below_ground = 1
        number_of_stories_below_ground_source = "Inferred"
      end
    else
      number_of_stories_above_ground = number_of_stories
      number_of_stories_above_ground_source = "Inferred"
      number_of_stories_below_ground = 0
      number_of_stories_below_ground_source = "Inferred"
    end
    
    if roof_elevation.nil? || surface_elevation.nil?
      surface_elevation = -number_of_stories_below_ground * assumed_floor_to_floor_height
      surface_elevation_source = "Inferred"
      roof_elevation = number_of_stories_above_ground * assumed_floor_to_floor_height
      roof_elevation_source = "Inferred"
    end
    
    if floor_area.nil?
      floor_area = footprint_area * number_of_stories
      floor_area_source = "Inferred" 
    end
    
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
     data['surface_elevation'] = surface_elevation
     data['surface_elevation_source'] = surface_elevation_source

    return errors
  end

  def infer_space_type(data)
    errors = []
    
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
    
    return errors
  end
  
  def clean_building(data, schema)
    errors = []
    
    if data['type'] == 'building'
      data['type'] = 'Building'
    end
    
    if data['source_id'].class == Fixnum
      data['source_id'] = data['source_id'].to_s
    end
    
    if data['zoning'] == "VACANT"      
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "MIXED"      
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "RETAIL/ENT"      
      data['zoning'] = "Commercial"      
    elsif data['zoning'] == "VISITOR"      
      data['zoning'] = "Commercial"      
    elsif data['zoning'] == "RESIDENT"      
      data['zoning'] = "Residential"           
    elsif data['zoning'] == "MISSING DATA"      
      data['zoning'] = "Vacant"  
    elsif data['zoning'] == "CIE"      
      data['zoning'] = "Commercial"          
    elsif data['zoning'] == "MIXRES"      
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "MIPS"      
      data['zoning'] = "Mixed"      
    end
    
    errors.concat( infer_geometry(data) )
    errors.concat( infer_space_type(data) )
    
    errors.concat( super(data, schema) )
    return errors
  end

  def clean_taxlot(data, schema)
    errors = []

    if data['type'] == 'taxlot'
      data['type'] = 'Taxlot'
    end
    
    if data['source_id'].class == Fixnum
      data['source_id'] = data['source_id'].to_s
    end
    
    if data['census_tract'].class == Fixnum
      data['census_tract'] = data['census_tract'].to_s
    end
    
    if data['zoning'] == "VACANT"      
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "MIXED"      
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "RETAIL/ENT"      
      data['zoning'] = "Commercial"      
    elsif data['zoning'] == "VISITOR"      
      data['zoning'] = "Commercial"      
    elsif data['zoning'] == "RESIDENT"      
      data['zoning'] = "Residential"  
    elsif data['zoning'] == "MISSING DATA"      
      data['zoning'] = "Vacant"
    elsif data['zoning'] == "CIE"      
      data['zoning'] = "Commercial" 
    elsif data['zoning'] == "MIXRES"      
      data['zoning'] = "Mixed"      
    elsif data['zoning'] == "MIPS"      
      data['zoning'] = "Mixed"      
    end   
    
    if data['zoning_source'] == "NREL_GDS"      
      data['zoning_source'] = nil
    end  
    
    errors.concat( super(data, schema) )
    return errors
  end
  
  def clean_region(data, schema)
    errors = []

    if data['type'] == 'region'
      data['type'] = 'Region'
    end
    
    if data['source_id'].class == Fixnum
      data['source_id'] = data['source_id'].to_s
    end
    
    errors.concat( super(data, schema) )
    return errors
  end


  
end

cleaner = SanFranciscoCleaner.new 
#cleaner.clean_originals
cleaner.gather_stats
#cleaner.clean
