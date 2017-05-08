def merge_workflow(workflow, instructions)
  instructions.each do |instruction|
    workflow[:steps].each do |step|
      if step[:measure_dir_name] == instruction[:measure_dir_name]
        arguments = step[:arguments]
        puts "Setting '#{instruction[:argument]}' of '#{step[:measure_dir_name]}' to '#{instruction[:value]}'"
        arguments[instruction[:argument]] = instruction[:value]
      end
    end
  end

  return workflow
end

# configure a workflow with feature, and region data
def configure_workflow(workflow, feature, project, is_retrofit = false)

  # configure with region first
  workflow = merge_workflow(workflow, map_project_properties(project[:properties]))

  # configure with feature next
  if feature[:properties][:type] == "Building"
    workflow = merge_workflow(workflow, map_building_properties(feature[:properties]))
  elsif feature[:properties][:type] == "District System"
    workflow = merge_workflow(workflow, map_district_system_properties(feature[:properties]))
  end
  
  # weather_file comes from the project properties
  workflow[:weather_file] = project[:properties][:weather_file_name]
  
  # remove keys with null values
  workflow[:steps].each do |step|
    arguments = step[:arguments]
    arguments.each_key do |name|
      if name == :__SKIP__
        if is_retrofit
          # don't skip retrofit measures
          arguments[name] = false  
        end
      elsif arguments[name].nil?
        arguments.delete(name)
      end 
    end
  end
  
  return workflow
end

def map_project_properties(properties)
  result = []
  
  properties.each_key do |name|
    
    value = properties[name]
    case name
    when :climate_zone
      next if value.nil?
      result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => :climate_zone, :value => value}
      
    when :weather_file_name
      next if value.nil?
      result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => :weather_file_name, :value => value}
      
    else
      puts "Unmapped project property '#{name}' with value '#{value}'"
    end
  end
  
  return result
end

def map_building_type(value, floor_area, number_of_stories)
  # TODO: find real cut off values based on square footage
  case value
  
  when "Education"
    value = "PrimarySchool"
    
  when "Enclosed mall"
    value = "RetailStripmall"
    
  when "Food sales"
    value = "SuperMarket"
    
  when "Food service"
    value = "FullServiceRestaurant"
    
  when "Inpatient health care"
    value = "Outpatient"
    
  when "Laboratory"
    value = "Hospital"
    
  when "Lodging"
    if number_of_stories
      if number_of_stories.to_i > 3
        value = "LargeHotel"
      else
        value = "SmallHotel"
      end
    end
    
  when "Mixed use"
    # no-op
    
  when "Mobile Home"
    value = "MidriseApartment"
    
  when "Multifamily (2 to 4 units)"
    value = "MidriseApartment"
    
  when "Multifamily (5 or more units)"
    value = "MidriseApartment"
    
  when "Nonrefrigerated warehouse"
    value = "Warehouse"
    
  when "Nursing"
    value = "Outpatient"
    
  when "Office"
    if floor_area
      if floor_area.to_f < 20000
        value = "SmallOffice"
      elsif floor_area.to_f > 100000
        value = "LargeOffice"
      else
        value = "MediumOffice"
      end
    end
  
  when "Outpatient health care"
    value = "Outpatient"
    
  when "Public assembly"
    value = "MediumOffice"
    
  when "Public order and safety"
    value = "MediumOffice"
    
  when "Refrigerated warehouse"
    value = "SuperMarket"
    
  when "Religious worship"
    value = "MediumOffice"
    
  when "Retail other than mall"
    value = "RetailStandalone"
    
  when "Service"
    value = "MediumOffice"
    
  when "Single-Family"
    value = "MidriseApartment"
    
  when "Strip shopping mall"
    value = "RetailStripmall"
    
  when "Vacant"
    value = "Warehouse"
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
      
      value = map_building_type(value, properties[:floor_area], properties[:number_of_stories])
      if value == "Mixed use"
      
        mixed_type_1 = properties[:mixed_type_1]
        mixed_type_1 = map_building_type(mixed_type_1)
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_a, :value => mixed_type_1}
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_a_num_units, :value => 1}
        
        mixed_type_2 = properties[:mixed_type_2]
        mixed_type_2_percentage = properties[:mixed_type_2_percentage].to_f / 100.0
        if mixed_type_2 and mixed_type_2_percentage
          mixed_type_2 = map_building_type(mixed_type_2)
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_b, :value => mixed_type_2}
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_b_fract_bldg_area, :value => mixed_type_2_percentage}
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_b_num_units, :value => 1}
        end
        
        mixed_type_3 = properties[:mixed_type_3]
        mixed_type_3_percentage = properties[:mixed_type_3_percentage].to_f / 100.0
        if mixed_type_3 and mixed_type_3_percentage
          mixed_type_3 = map_building_type(mixed_type_3)
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_c, :value => mixed_type_3}
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_c_fract_bldg_area, :value => mixed_type_3_percentage}
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_c_num_units, :value => 1}
        end
        
        mixed_type_4 = properties[:mixed_type_4]
        mixed_type_4_percentage = properties[:mixed_type_4_percentage].to_f / 100.0
        if mixed_type_4 and mixed_type_4_percentage
          mixed_type_4 = map_building_type(mixed_type_4)
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_d, :value => mixed_type_4}
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_d_fract_bldg_area, :value => mixed_type_4_percentage}
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_d_num_units, :value => 1}
        end
        
      else
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_a, :value => value}
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_a_num_units, :value => 1}
        
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_b, :value => value}
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_b_fract_bldg_area, :value => 0.0}
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_b_num_units, :value => 0}       

        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_c, :value => value}
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_c_fract_bldg_area, :value => 0.0}
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_c_num_units, :value => 0}  

        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_d, :value => value}
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_d_fract_bldg_area, :value => 0.0}
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_d_num_units, :value => 0}          
      end

    when :floor_area
      next if value.nil?
      result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :total_bldg_floor_area, :value => value}

    when :include_in_energy_analysis
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
     
    when :maximum_roof_height
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}

    when :number_of_stories
      next if value.nil?
      
      num_stories_above_grade = properties[:number_of_stories_above_ground]
      if num_stories_above_grade.nil? 
        num_stories_above_grade = value
      end
      
      num_stories_below_grade = value - num_stories_above_grade
      
      result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :num_stories_above_grade, :value => num_stories_above_grade}
      result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :num_stories_below_grade, :value => num_stories_below_grade}
      
      if value == 0
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :num_stories_above_grade, :value => 1}
      end
      
    when :number_of_residential_units
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}

    when :roof_type
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :surface_elevation
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}
      
    when :tariff_filename
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}

    when :year_built
      next if value.nil?
      #result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => 'weather_file_name', :value => value}

    when :number_of_stories_above_ground
      # no-op, handled under number_of_stories
      
    when :mixed_type_1, :mixed_type_1_percentage, :mixed_type_2, :mixed_type_2_percentage, :mixed_type_3, :mixed_type_3_percentage, :mixed_type_4, :mixed_type_4_percentage
      # no-op, handled under building_type
      
    when :address, :created_at, :footprint_area, :footprint_perimeter, :geojson_id, :id, :legal_name, :name, :project_id, :source_id, :source_name, :type, :updated_at
      # no-op

    else 
      puts "Unmapped building property '#{name}' with value '#{value}'"
    end
  
  end
  
  return result
end

def map_district_system_properties(properties)
  result = []
  
  properties.each_key do |name|
    
    value = properties[name]
    case name
    when :district_system_type
      next if value.nil?
      result << {:measure_dir_name => 'add_district_system', :argument => :district_system_type, :value => value}
      
     else 
      puts "Unmapped building property '#{name}' with value '#{value}'"
    end
  end
  
  return result
end