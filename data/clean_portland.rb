require 'rubygems'
require 'json-schema'
require_relative 'clean_common.rb'

#  Data from:
#    http://www.civicapps.org/datasets/building-footprints-portland
#
#  Zoning code definitions:
#    https://www.portlandoregon.gov/bps/article/64609

class PortlandCleaner < Cleaner
  
  def name()
    return "Portland"
  end
  
  # return a string that will match files to clean in glob
  def file_pattern()
    return "US_OR_*.geojson"
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
    
    if total_height.nil?
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

    if data['type'] == 'building'
      data['type'] = 'Building'
    end
    
    if data['source_id'].class == Fixnum
      data['source_id'] = data['source_id'].to_s
    end
    
    if data['zoning'] == "CG" # General Commercial
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "CM" # Mixed Commercial/Residential
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "CN1" # Neighborhood Commercial 1 
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "CN2" # Neighborhood Commercial 2
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "CO1" # Office Commercial 1
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "CO2" # Office Commercial 2
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "CS" # Storefront Commercial
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "CX" # Central Commercial
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "EG1"   # General Employment 1   
      data['zoning'] = "Commercial"      
    elsif data['zoning'] == "EG2"   # General Employment 2
      data['zoning'] = "Commercial"     
    elsif data['zoning'] == "EX"    # Central Employment
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "IG1" # General Industrial 1
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "IG2" # General Industrial 2
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "IR"   # Residential Institutional
      data['zoning'] = "Mixed"   
    elsif data['zoning'] == "OS"   # Open Space
      data['zoning'] = "OpenSpace"              
    elsif data['zoning'] == "R1"   # Medium density multi-dwelling zone
      data['zoning'] = "Residential"      
    elsif data['zoning'] == "R2"   # Low density multi-dwelling zone
      data['zoning'] = "Residential"   
    elsif data['zoning'] == "R3"   # Low density multi-dwelling zone
      data['zoning'] = "Residential"   
    elsif data['zoning'] == "R5"   # 1 unit per 5,000 sq. ft.
      data['zoning'] = "Residential" 
    elsif data['zoning'] == "R7"   # 1 unit per 7,000 sq. ft.
      data['zoning'] = "Residential" 
    elsif data['zoning'] == "R10"   # 1 unit per 10,000 sq. ft.
      data['zoning'] = "Residential" 
    elsif data['zoning'] == "R20"   # 1 unit per 20,000 sq. ft.
      data['zoning'] = "Residential"   
    elsif data['zoning'] == "RF"   # 1 unit per 87,120 sq. ft.
      data['zoning'] = "Residential" 
    elsif data['zoning'] == "RH"   # High density multi-dwelling zone
      data['zoning'] = "Residential"   
    elsif data['zoning'] == "RX"   # High density multi-dwelling zone
      data['zoning'] = "Residential"   
    end   
    
    data.each do |k,v|
      if v == 'Assesor'
        data[k] = 'Assessor'
      end
      if /_source$/.match(k)
        if data[k.gsub('_source','')].nil?
          data.delete(k)
        end
      end
    end
    
    # roof type
    if data['roof_type'] == 'Asphalt Shingle'
      data.delete('roof_type')
    elsif data['roof_type'] == 'Metal'
      data.delete('roof_type')  
    elsif data['roof_type'] == 'Multi-level'
      data['roof_type'] = 'Multi-level Flat'
    elsif data['roof_type'] == 'Wood Shake'
      data.delete('roof_type')
    end
    
    # DLM: Portland has the best height data
    
    # "minimum_roof_height": { "count": 297, "values": "Min = 2.112263945136, Max = 36.36264092964", "percent": 15.46 }
    # "average_roof_height": { "count": 1836, "values": "Min = 1.532491487208, Max = 74.9808", "percent": 95.58 }
    # "maximum_roof_height": { "count": 297, "values": "Min = 3.172967951232, Max = 42.99508725324", "percent": 15.46 }
    # "roof_elevation": { "count": 1836, "values": "Min = 11.8872, Max = 113.035079530608", "percent": 95.58 }
    # "surface_elevation": { "count": 1921, "values": "Min = 2.1336, Max = 91.326453441216", "percent": 100.0 }
    # "number_of_stories": {  "count": 1907, "values": "Min = 1, Max = 42", "percent": 99.27 }
    # "floor_area": { "count": 1921, "values": "Min = 3.7161216, Max = 118232.1248256", "percent": 100.0 }
    
    # convert from feet to meters
    #ft_to_m = 0.3048
    #data['average_roof_height'] = ft_to_m*data['average_roof_height'] if data['average_roof_height']
    #data['footprint_perimeter'] = ft_to_m*data['footprint_perimeter'] if data['footprint_perimeter']
    #data['maximum_roof_height'] = ft_to_m*data['maximum_roof_height'] if data['maximum_roof_height']
    #data['minimum_roof_height'] = ft_to_m*data['minimum_roof_height'] if data['minimum_roof_height']
    #data['roof_elevation'] = ft_to_m*data['roof_elevation'] if data['roof_elevation']
    #data['surface_elevation'] = ft_to_m*data['surface_elevation'] if data['surface_elevation']
    
    # convert from square feet to square meters
    #ft2_to_m2 = 0.092903
    #data['floor_area'] = ft_to_m*data['floor_area'] if data['floor_area']
    #data['footprint_area'] = ft_to_m*data['footprint_area'] if data['footprint_area']

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
    
    if data['zoning'] == "CG" # General Commercial
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "CM" # Mixed Commercial/Residential
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "CN1" # Neighborhood Commercial 1 
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "CN2" # Neighborhood Commercial 2
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "CO1" # Office Commercial 1
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "CO2" # Office Commercial 2
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "CS" # Storefront Commercial
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "CX" # Central Commercial
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "EG1"   # General Employment 1   
      data['zoning'] = "Commercial"      
    elsif data['zoning'] == "EG2"   # General Employment 2
      data['zoning'] = "Commercial"     
    elsif data['zoning'] == "EX"    # Central Employment
      data['zoning'] = "Mixed"
    elsif data['zoning'] == "IG1" # General Industrial 1
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "IG2" # General Industrial 2
      data['zoning'] = "Commercial"
    elsif data['zoning'] == "IR"   # Residential Institutional
      data['zoning'] = "Mixed"   
    elsif data['zoning'] == "OS"   # Open Space
      data['zoning'] = "OpenSpace"        
    elsif data['zoning'] == "R1"   # Medium density multi-dwelling zone
      data['zoning'] = "Residential"      
    elsif data['zoning'] == "R2"   # Low density multi-dwelling zone
      data['zoning'] = "Residential"   
    elsif data['zoning'] == "R3"   # Low density multi-dwelling zone
      data['zoning'] = "Residential"   
    elsif data['zoning'] == "R5"   # 1 unit per 5,000 sq. ft.
      data['zoning'] = "Residential" 
    elsif data['zoning'] == "R7"   # 1 unit per 7,000 sq. ft.
      data['zoning'] = "Residential" 
    elsif data['zoning'] == "R10"   # 1 unit per 10,000 sq. ft.
      data['zoning'] = "Residential" 
    elsif data['zoning'] == "R20"   # 1 unit per 20,000 sq. ft.
      data['zoning'] = "Residential"   
    elsif data['zoning'] == "RF"   # 1 unit per 87,120 sq. ft.
      data['zoning'] = "Residential" 
    elsif data['zoning'] == "RH"   # High density multi-dwelling zone
      data['zoning'] = "Residential"   
    elsif data['zoning'] == "RX"   # High density multi-dwelling zone
      data['zoning'] = "Residential"   
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

cleaner = PortlandCleaner.new 
#cleaner.clean_originals
cleaner.gather_stats
cleaner.clean
cleaner.write_csvs