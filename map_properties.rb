def map_region_properties(properties)
  result = []
  
  properties.each_key do |name|
    
    value = properties[name]
    case name
    when :climate_zone
      next if value.nil?
      result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'climate_zone', :value => value}
      
    else
      puts "Unmapped region property '#{name}' with value '#{value}'"
    end
  end
end

def map_building_properties(properties)
  result = []
  
  properties.each_key do |name|
    
    value = properties[name]
    case name
    when :building_status
      next if value.nil?
      #result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => 'bldg_type_a', :value => value}
      
    when :building_type
      next if value.nil?
      result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => 'bldg_type_a', :value => value}
      
    when :cooling_source
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :floor_area
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :heating_source
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :heating_source
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
      include_in_energy_analysis
    when :maximum_roof_height
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}

    when :number_of_stories
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :number_of_residential_units
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}

    when :num_floors
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :project_id
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :roof_type
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :surface_elevation
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :system_type
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :tariff_filename
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}

    when :total_bldg_area_ip
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :weather_file_name
      next if value.nil?
      result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :year_built
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}

    when :number_of_stories_above_ground
      # no-op, handled under number_of_stories
      
    when :mixed_type_1, :mixed_type_1_percentage, :mixed_type_2, :mixed_type_2_percentage, :mixed_type_3, :mixed_type_3_percentage, :mixed_type_4, :mixed_type_4_percentage
      # no-op, handled under building_type
      
    when :address, :created_at, :footprint_area, :footprint_perimeter :geojson_id, :id, :legal_name, :name, :source_id, :source_name, :type, :updated_at
      # no-op

    else 
      puts "Unmapped building property '#{name}' with value '#{value}'"
    end
  
    "include_in_energy_analysis": {
      "description": "Include this building's energy use and cost in the analysis. Defaults to true. Fixed parameter.",
      "type": "boolean"
    }
    
  
  end
  
  return result
end