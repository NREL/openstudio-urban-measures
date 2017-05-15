######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

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
    floor_area = data['floor_area']
    footprint_area = data['footprint_area'] 
    maximum_roof_height = data['maximum_roof_height']
    minimum_roof_height = data['minimum_roof_height']
    number_of_stories = data['number_of_stories']
    number_of_stories_above_ground = data['number_of_stories_above_ground']
    number_of_stories_below_ground = data['number_of_stories_below_ground']
    roof_elevation = data['roof_elevation']
    roof_type = data['roof_type']
    surface_elevation = data['surface_elevation']
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
    
    if roof_type == "Pitched"
     roof_type = "Gable"
    elsif roof_type == "Complex"
     roof_type = "Hip"
    elsif roof_type == "Multi-level Flat"
     roof_type = "Flat"
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
      elsif num_floors_height
        number_of_stories = num_floors_height.round
      elsif num_floors_area
        number_of_stories = num_floors_area.round
      else
        number_of_stories = 1
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
        number_of_stories_below_ground = 0
      else
        number_of_stories_above_ground = number_of_stories-1
        number_of_stories_below_ground = 1
      end
    else
      number_of_stories_above_ground = number_of_stories
      number_of_stories_below_ground = 0
    end
    
    if roof_elevation.nil? || surface_elevation.nil?
      surface_elevation = -number_of_stories_below_ground * assumed_floor_to_floor_height
      roof_elevation = number_of_stories_above_ground * assumed_floor_to_floor_height
    end
    
    if floor_area.nil?
      floor_area = footprint_area * number_of_stories
    end
    
     data['average_roof_height'] = average_roof_height
     data['floor_area'] = floor_area
     data['footprint_area'] = footprint_area
     data['maximum_roof_height'] = maximum_roof_height
     data['minimum_roof_height'] = minimum_roof_height
     data['number_of_stories'] = number_of_stories
     data['number_of_stories_above_ground'] = number_of_stories_above_ground
     data['number_of_stories_below_ground'] = number_of_stories_below_ground
     data['roof_elevation'] = roof_elevation
     data['roof_type'] = roof_type
     data['surface_elevation'] = surface_elevation

  end

  def infer_building_type(data)

    zoning = data['zoning']
    floor_area = data['floor_area']
    number_of_stories = data['number_of_stories']
    building_type = data['building_type']
    number_of_residential_units = data['number_of_residential_units']
    
    if floor_area.nil?
      fail "Floor area cannot be nil"
    end
    
    if zoning.nil?
      zoning = "Vacant"
    end
    
    ft2_to_m2 = 0.092903
    
    if building_type.nil?
      if zoning == "Vacant"
        building_type = "Vacant"
      elsif zoning == "Mixed"
        if floor_area < 3000*ft2_to_m2
          building_type = "Single-Family"
        elsif floor_area < (4*2000)*ft2_to_m2
          building_type = "Multifamily (2 to 4 units)"
        else
          building_type = "Multifamily (5 or more units)"
        end
      elsif zoning == "Residential"
        if floor_area < 3000*ft2_to_m2
          building_type = "Single-Family"
        elsif floor_area < (4*2000)*ft2_to_m2
          building_type = "Multifamily (2 to 4 units)"
        else
          building_type = "Multifamily (5 or more units)"
        end
      elsif zoning == "Commercial"
        building_type = "Office"
      elsif zoning == "OpenSpace"
        building_type = "Vacant"        
      end
    end
        
    if number_of_residential_units.nil?
      if building_type == "Single-Family"
        number_of_residential_units = 1
      elsif building_type == "Multifamily (2 to 4 units)"
        number_of_residential_units = (floor_area / (2000*ft2_to_m2)).to_i
        if number_of_residential_units < 2
          number_of_residential_units = 2
        elsif number_of_residential_units > 4
          number_of_residential_units = 4
        end
      elsif building_type == "Multifamily (5 or more units)"
        number_of_residential_units = (floor_area / (1500*ft2_to_m2)).to_i
        if number_of_residential_units < 5
          number_of_residential_units = 5
        end
      end
    end
    
    data['zoning'] = zoning
    data['building_type'] = building_type
    data['number_of_residential_units'] = number_of_residential_units
    
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
    infer_building_type(data) 
    
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
    
    data['weather_file_name'] = 'USA_OR_Portland.726980_TMY2.epw'
    
    super(data, schema)
  end
  


end

cleaner = PortlandCleaner.new 
#cleaner.clean_originals
#cleaner.gather_stats
cleaner.clean
cleaner.write_csvs