######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

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
    
    # DLM: NA for LA
    # check that our resulting floor area is not too much larger than the reported area
    #if footprint_area && floor_area
    #  resulting_area = footprint_area * number_of_stories
    #  if resulting_area > 1.2 * floor_area
    #    new_result = [1, number_of_stories - 1].max
    #    new_resulting_area = footprint_area * new_result
    #    if (floor_area-new_resulting_area).abs < (floor_area-resulting_area).abs
    #      number_of_stories = new_result
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
    #    number_of_stories_below_ground = 0
    #  else
    #    number_of_stories_above_ground = number_of_stories-1
    #    number_of_stories_below_ground = 1
    #  end
    #else
      number_of_stories_above_ground = number_of_stories
      number_of_stories_below_ground = 0
    #end
    
    # DLM: NA for LA
    #if roof_elevation.nil? && surface_elevation.nil?
    #  surface_elevation = 0
    #  roof_elevation = number_of_stories_above_ground * assumed_floor_to_floor_height
    #elsif roof_elevation.nil? 
    #  roof_elevation = surface_elevation + number_of_stories_above_ground * assumed_floor_to_floor_height
    #elsif surface_elevation.nil?
    #  surface_elevation = roof_elevation - number_of_stories_above_ground * assumed_floor_to_floor_height
    #end
    
    #if floor_area.nil?
    #  floor_area = footprint_area * number_of_stories
    #end
    
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
    
    if zoning.nil?
      zoning = "Vacant"
    end
    
    if building_type.nil?
      if zoning == "Vacant"
        building_type = "Vacant"
      elsif zoning == "Mixed"
        if floor_area < 300
          building_type = "Single-Family"
        elsif floor_area < 500
          building_type = "Multifamily (2 to 4 units)"
        else
          building_type = "Multifamily (5 or more units)"
        end
      elsif zoning == "Residential"
        if floor_area < 300
          building_type = "Single-Family"
        elsif floor_area < 500
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

    if data['BLD_ID']
      data['source_id'] = data['BLD_ID'].to_s
    end
    
    if data['SOURCE']
      data['source_name'] = data['SOURCE'].to_s
    end
    
    ft_to_m = 0.3048
    
    if data['ELEV']
      data['surface_elevation'] = ft_to_m*data['ELEV'].to_f
      if data['HEIGHT']
        data['roof_elevation'] = data['surface_elevation'] + ft_to_m*data['HEIGHT'].to_f
      end
    end
    
    # make up
    data['zoning'] = "Commercial"
    data['intersecting_building_source_ids'] = []
    data['floor_area'] = 100
    
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
    
    data['weather_file_name'] = 'USA_CA_Los.Angeles.Intl.AP.722950_TMY3.epw'
    
    super(data, schema)
  end

end

cleaner = LACleaner.new 
#cleaner.clean_originals
#cleaner.gather_stats
cleaner.clean
cleaner.write_csvs