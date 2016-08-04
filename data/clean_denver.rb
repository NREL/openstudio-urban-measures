require 'rubygems'
require 'json-schema'
require_relative 'clean_common.rb'

#  Data from:
#    http://data.denvergov.org/dataset/city-and-county-of-denver-building-outlines

class DenverCleaner < Cleaner

  def name()
    return "Denver"
  end
  
  # return a string that will match files to clean in glob
  def file_pattern()
    return "US_CO_*.geojson"
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
    
    if average_roof_height == 0
      average_roof_height = nil
    end
    
    if surface_elevation && roof_elevation
      total_height = roof_elevation.to_f - surface_elevation.to_f
    elsif average_roof_height
      total_height = average_roof_height.to_f
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
    
    # DLM: NA for Denver
    # check that our resulting floor area is not too much larger than the reported area
    #if footprint_area && floor_area
    #  resulting_area = footprint_area * number_of_stories
    #  if resulting_area > 1.2 * floor_area
    #    new_result = [1, number_of_stories - 1].max
    #    new_resulting_area = footprint_area * new_result
    #    if (floor_area-new_resulting_area).abs < (floor_area-resulting_area).abs
    #      number_of_stories = new_result
    #      total_height = number_of_stories * assumed_floor_to_floor_height
    #    end
    #  end
    #end

    # DLM: NA for Denver
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
    
    # DLM: NA for Denver
    #if roof_elevation.nil? && surface_elevation.nil?
    #  surface_elevation = 0
    #  roof_elevation = number_of_stories_above_ground * assumed_floor_to_floor_height
    #elsif roof_elevation.nil? 
      roof_elevation = surface_elevation + number_of_stories_above_ground * assumed_floor_to_floor_height
    #elsif surface_elevation.nil?
    #  surface_elevation = roof_elevation - number_of_stories_above_ground * assumed_floor_to_floor_height
    #end
    
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
      zoning_source = "Inferred"
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
    
    # DLM: Denver does not have number_of_stories but it does have number_of_stories
    
    # "minimum_roof_height": { "count": 0, "values": "No data", "percent": 0.0 }
    # "average_roof_height": { "count": 22657, "values": "Min = 0.0, Max = 62.7888", "percent": 100.0 }
    # "maximum_roof_height": { "count": 0, "values": "No data", "percent": 0.0 }
    # "roof_elevation": { "count": 0, "values": "No data", "percent": 0.0 }
    # "surface_elevation": { "count": 19365, "values": "Min = 1566.924984, Max = 1653.838704", "percent": 100.0 }
    # "number_of_stories": { "count": 0, "values": "No data", "percent": 0.0 }
    # "floor_area": { "count": 0, "values": "No data", "percent": 0.0 }
    
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
    
    data['weather_file_name'] = 'USA_CO_Denver.Intl.AP.725650_TMY3.epw'
    
    super(data, schema)
  end

end

cleaner = DenverCleaner.new 
#cleaner.clean_originals
#cleaner.gather_stats
cleaner.clean
cleaner.write_csvs