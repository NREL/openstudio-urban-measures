######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

module UrbanOptMapping

def merge_workflow(workflow, instructions)
  instructions.each do |instruction|
    workflow[:steps].each do |step|
      if instruction[:measure_dir_name] && step[:measure_dir_name] == instruction[:measure_dir_name]
        arguments = step[:arguments]
        @logger.debug("Setting '#{instruction[:argument]}' of '#{step[:measure_dir_name]}' to '#{instruction[:value]}'") if @logger
        arguments[instruction[:argument]] = instruction[:value]
      elsif instruction[:measure_step_name] && step[:name] == instruction[:measure_step_name]
        arguments = step[:arguments]
        @logger.debug("Setting '#{instruction[:argument]}' of '#{step[:name]}' to '#{instruction[:value]}'") if @logger
        arguments[instruction[:argument]] = instruction[:value]        
      end
    end
  end

  return workflow
end

# configure a workflow with feature, and region data
def configure_workflow(workflow, feature, project, is_retrofit = false)

  # make 'properties' array for project (just weather_file_name and climate_zone for now)
  # TODO: there could be other project-level properties that need to be mapped to measure inputs in the future
  prop = {}
  prop[:weather_file_name] = project[:weather_filename]
  prop[:climate_zone] = project[:climate_zone]

  selected_template = project.key?("template") ? project[:template] : nil

  # configure with region first
  workflow = merge_workflow(workflow, map_project_properties(prop))

  # configure with feature next
  if feature[:properties][:type] == "Building"
    workflow = merge_workflow(workflow, map_building_properties(feature[:properties], selected_template))
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
      @logger.warn("Unmapped project property '#{name}' with value '#{value}'") if @logger
    end
  end
  
  return result
end

def map_building_type(value, floor_area=nil, number_of_stories=nil, num_units=nil, template=nil)
  # TODO: find real cut off values based on square footage
  case value
  
  when "Education"
    value = "PrimarySchool"
    num_units = 1
    
  when "Enclosed mall"
    value = "RetailStripmall"
    num_units = 1
    
  when "Food sales"
    #value = "SuperMarket" # not working
    value = "FullServiceRestaurant"
    num_units = 1
    
  when "Food service"
    value = "FullServiceRestaurant"
    num_units = 1
    
  when "Inpatient health care"
    value = "Outpatient"
    num_units = 1
    
  when "Laboratory"
    value = "Hospital"
    num_units = 1
    
  when "Lodging"
    if number_of_stories
      if number_of_stories.to_i > 3
        value = "LargeHotel"
      else
        value = "SmallHotel"
      end
    end
    num_units = 1
    
  when "Mixed use"
    value = "Mixed use"
    
  when "Mobile Home"
    value = "MidriseApartment"
    
  when "Multifamily (2 to 4 units)"
    value = "MidriseApartment"
    if num_units < 2 or num_units > 4
      num_units = 2
    end
    
  when "Multifamily (5 or more units)"
    value = "MidriseApartment"
    if num_units < 5
      num_units = 5
    end      
    
  when "Nonrefrigerated warehouse"
    value = "Warehouse"
    num_units = 1
    
  when "Nursing"
    value = "Outpatient"
    num_units = 1
    
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
    num_units = 1
  
  when "Outpatient health care"
    value = "Outpatient"
    num_units = 1
    
  when "Public assembly"
    value = "MediumOffice"
    num_units = 1
    
  when "Public order and safety"
    value = "MediumOffice"
    num_units = 1
    
  when "Refrigerated warehouse"
    #value = "SuperMarket" # not working
    value = "Warehouse"
    num_units = 1
    
  when "Religious worship"
    value = "MediumOffice"
    num_units = 1
    
  when "Retail other than mall"
    value = "RetailStandalone"
    num_units = 1
    
  when "Service"
    value = "MediumOffice"
    num_units = 1
    
  when "Single-Family"
    value = "MidriseApartment"
    num_units = 1
    
  when "Strip shopping mall"
    value = "RetailStripmall"
    num_units = 1
    
  when "Vacant"
    value = "Warehouse"
    num_units = 1
    
  end
  
  return value, num_units
      
end

def map_building_properties(properties, template = nil)
  result = []
  
  # default properties
  if properties[:number_of_stories].nil?
    if properties[:number_of_stories_above_ground]
      properties[:number_of_stories] = properties[:number_of_stories_above_ground]
    else
      properties[:number_of_stories] = 1
    end
  end
  
  if properties[:floor_area].nil?
    if properties[:footprint_area]
      if properties[:number_of_stories] > 0
        properties[:floor_area] = properties[:footprint_area]*properties[:number_of_stories]
      else
        properties[:floor_area] = properties[:footprint_area]
      end
    end
  end  
  
  # map properties
  properties.each_key do |name|
    
    value = properties[name]
    case name
    when :building_status
      next if value.nil?
      #result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => 'bldg_type_a', :value => value}
    
    when :building_type
      next if value.nil?
      
      number_of_residential_units = properties[:number_of_residential_units]
      if number_of_residential_units.nil?
        number_of_residential_units = 1
      end
      
      value, num_units = map_building_type(value, properties[:floor_area], properties[:number_of_stories], number_of_residential_units, template)

      if value == "Mixed use"
        
        mixed_type_1 = properties[:mixed_type_1]
        mixed_type_1_percentage = properties[:mixed_type_1_percentage].to_f / 100.0
        
        mixed_type_2 = properties[:mixed_type_2]
        mixed_type_2_percentage = properties[:mixed_type_2_percentage].to_f / 100.0
        
        mixed_type_3 = properties[:mixed_type_3]
        mixed_type_3_percentage = properties[:mixed_type_3_percentage].to_f / 100.0
        
        mixed_type_4 = properties[:mixed_type_4]
        mixed_type_4_percentage = properties[:mixed_type_4_percentage].to_f / 100.0
        
        if mixed_type_1 and mixed_type_1_percentage
          mixed_type_1, mixed_type_1_num_units = map_building_type(mixed_type_1, properties[:floor_area], properties[:number_of_stories], number_of_residential_units, template)
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_a, :value => mixed_type_1}
          result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_a_num_units, :value => mixed_type_1_num_units}
        end

        if mixed_type_2 and mixed_type_2_percentage
          mixed_type_2, mixed_type_2_num_units = map_building_type(mixed_type_2, properties[:floor_area], properties[:number_of_stories], number_of_residential_units, template)
          if mixed_type_1 == mixed_type_2
            mixed_type_2 = nil
          end
          if mixed_type_2
            result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_b, :value => mixed_type_2}
            result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_b_fract_bldg_area, :value => mixed_type_2_percentage}
            result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_b_num_units, :value => mixed_type_2_num_units}
          end
        end

        if mixed_type_3 and mixed_type_3_percentage
          mixed_type_3, mixed_type_3_num_units = map_building_type(mixed_type_3, properties[:floor_area], properties[:number_of_stories], number_of_residential_units, template)
          if mixed_type_1 == mixed_type_3 or mixed_type_2 == mixed_type_3
            mixed_type_3 = nil
            result.each do |argument|
              next unless argument[:argument] == :bldg_type_b_fract_bldg_area
              argument[:value] += mixed_type_3_percentage
            end            
          end
          if mixed_type_3
            result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_c, :value => mixed_type_3}
            result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_c_fract_bldg_area, :value => mixed_type_3_percentage}
            result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_c_num_units, :value => mixed_type_3_num_units}
          end
        end

        if mixed_type_4 and mixed_type_4_percentage
          mixed_type_4, mixed_type_4_num_units = map_building_type(mixed_type_4, properties[:floor_area], properties[:number_of_stories], number_of_residential_units, template)
          if mixed_type_1 == mixed_type_4 or mixed_type_3 == mixed_type_4
            mixed_type_4 = nil
            result.each do |argument|
              next unless argument[:argument] == :bldg_type_c_fract_bldg_area
              argument[:value] += mixed_type_4_percentage
            end            
          end
          if mixed_type_4
            result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_d, :value => mixed_type_4}
            result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_d_fract_bldg_area, :value => mixed_type_4_percentage}
            result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_d_num_units, :value => mixed_type_4_num_units}
          end
        end
        
      else

        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_a, :value => value}
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :bldg_type_a_num_units, :value => num_units}
        
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

    when :exclude_hvac
      next if value.nil?
      result << {:measure_dir_name => 'remove_hvac_systems', :argument => 'remove_all_equipment', :value => value}

    when :number_of_stories_above_ground
      # no-op, handled under number_of_stories
      
    when :mixed_type_1, :mixed_type_1_percentage, :mixed_type_2, :mixed_type_2_percentage, :mixed_type_3, :mixed_type_3_percentage, :mixed_type_4, :mixed_type_4_percentage
      # no-op, handled under building_type
      
    when :address, :created_at, :footprint_area, :footprint_perimeter, :geojson_id, :id, :legal_name, :name, :project_id, :source_id, :source_name, :type, :updated_at
      # no-op
      
    when :fill, :"fill-opacity", :geometryType, :height, :stroke, :"stroke-opacity", :"stroke-width"
      # no-op
	  
	when :transformer_id
		# no-op
		
    else 
      @logger.warn("Unmapped building property '#{name}' with value '#{value}'") if @logger
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
      
      if value == 'Central Chilled Water'
        value = 'Central Hot and Chilled Water'
      elsif value == 'Central Hot Water'
        value = 'Central Hot and Chilled Water'
      elsif value == 'Central Hot and Cold Water'
        value = 'Central Hot and Chilled Water'
      elsif value == 'Central Ambient Water'
        value = 'Ambient Loop'  
      end
        
      result << {:measure_dir_name => 'add_district_system', :argument => :district_system_type, :value => value}
    
    when :transformer_rating
      # use transformer_rating for name_plate_rating argument. convert kVA to VA
      result << {:measure_dir_name => 'add_transformer', :argument => :name_plate_rating, :value => (value.to_f * 1000)}

    when :address, :created_at, :footprint_area, :footprint_perimeter, :geojson_id, :id, :legal_name, :name, :project_id, :source_id, :source_name, :type, :updated_at, :transformer_id, :transformer_phase, :transformer_voltage, :transformer_type
      # no-op
      
    when :surface_elevation, :floor_area, :number_of_stories, :maximum_roof_height

    when :fill, :"fill-opacity", :geometryType, :height, :stroke, :"stroke-opacity", :"stroke-width"
      # no-op
      
     else 
      @logger.warn("Unmapped district system property '#{name}' with value '#{value}'") if @logger
    end
  end
  
  return result
end

end