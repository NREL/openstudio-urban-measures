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
  prop[:cec_climate_zone] = project[:cec_climate_zone] 
  prop[:template] = project[:template]
  prop[:timesteps_per_hour] = project[:timesteps_per_hour]
  prop[:begin_date] = project[:begin_date]
  prop[:end_date] = project[:end_date]

  selected_template = project.key?(:template) ? project[:template] : nil
  #@logger.info("getting template #{project.inspect} selected template = #{selected_template}")

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
      next if !properties[:cec_climate_zone].nil?  # CEC climate zone takes precedence if set
      result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => :climate_zone, :value => value}
    
    when :cec_climate_zone
      # set climate zone type to CEC (default is ASHRAE) and climate zone when CEC climate zone is set
      next if value.nil?
      result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => :climate_zone, :value => value}
      result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => :climate_zone_type, :value => 'CEC'}

    when :weather_file_name
      next if value.nil?
      result << {:measure_dir_name => 'ChangeBuildingLocation', :argument => :weather_file_name, :value => value}

    when :template
      # template is used in multiple measures
      # note: this is the default, but may be adjusted later based on year-built argument in map_building_properties section
      @logger.info("**** setting template to default value: #{value}.  This may be modified based on year built")
      next if value.nil?
      result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :template, :value => value}
      result << {:measure_dir_name => 'create_typical_building_from_model_1', :argument => :template, :value => value}
      result << {:measure_dir_name => 'create_typical_building_from_model_2', :argument => :template, :value => value}
      result << {:measure_dir_name => 'swap_hvac_systems', :argument => :template, :value => value}

    when :timesteps_per_hour
      result << {:measure_dir_name => 'set_run_period', :argument => :timesteps_per_hour, :value => value}
    when :begin_date
      result << {:measure_dir_name => 'set_run_period', :argument => :begin_date, :value => value}
    when :end_date
      result << {:measure_dir_name => 'set_run_period', :argument => :end_date, :value => value}

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
    if template.include? "DEER"
      value = "EPr"
    else
      value = "PrimarySchool"
    end
    num_units = 1
    
  when "Enclosed mall"
    if template.include? "DEER"
      value = "RtL"
    else
      value = "RetailStripmall"
    end
    num_units = 1
    
  when "Food sales"
    #value = "SuperMarket" # not working
    if template.include? "DEER"
      value = "RSD"
    else
      value = "FullServiceRestaurant"
    end
    num_units = 1

  when "Food service"
    if template.include? "DEER"    
      value = "RSD"
    else
      value = "FullServiceRestaurant"
    end
    num_units = 1
    
  when "Inpatient health care"
    if template.include? "DEER" 
      value = "Nrs"
    else
      value = "Outpatient"
    end
    num_units = 1
    
  when "Laboratory"
    if template.include? "DEER"
      value = "Hsp"
    else
      value = "Hospital"
    end
    num_units = 1

  when "Lodging"
    if template.include? "DEER"
      value = "Htl"
    else
      if number_of_stories
        if number_of_stories.to_i > 3
          value = "LargeHotel"
        else
          value = "SmallHotel"
        end
      end
    end
    num_units = 1
    
  when "Mixed use"
    if template.include? "DEER"
      value = "ECC"
    else
      value = "Mixed use"
    end
    num_units = 1
    
  when "Mobile Home"
    if template.include? "DEER"
      value = "DMo"
    else
      value = "MidriseApartment"
    end
    num_units = 1
    
  when "Multifamily (2 to 4 units)"
    if template.include? "DEER"
      value = "MFm"
    else
      value = "MidriseApartment"
    end
    if num_units < 2 or num_units > 4
      num_units = 2
    end
    
  when "Multifamily (5 or more units)"
    if template.include? "DEER"
      value = "MFm"
    else
      value = "MidriseApartment"
    end
    if num_units < 5
      num_units = 5
    end
    
  when "Nonrefrigerated warehouse"
    if template.include? "DEER"
      value = "SUn"
    else
      value = "Warehouse"
    end
    num_units = 1

  when "Nursing"
    if template.include? "DEER"
      value = "Nrs"
    else
      value = "Outpatient"
    end
    num_units = 1
    
  when "Office"
    if template.include? "DEER"
      if floor_area
        if floor_area.to_f > 100000
          value = "OfL"
        else
          value = "OfS"
        end
      end
    else
      if floor_area
        if floor_area.to_f < 20000
          value = "SmallOffice"
        elsif floor_area.to_f > 100000
          value = "LargeOffice"
        else
          value = "MediumOffice"
        end
      end
    end
    num_units = 1
  
  when "Outpatient health care"
    if template.include? "DEER"
      value = "Nrs"
    else
      value = "Outpatient"
    end
    num_units = 1
    
  when "Public assembly"
    if template.include? "DEER"    
      value = "Asm"
    else
      value = "MediumOffice"
    end
    num_units = 1
    
  when "Public order and safety"    
    if template.include? "DEER"    
      value = "Asm"
    else
      value = "MediumOffice"
    end
    num_units = 1
    
  when "Refrigerated warehouse"
    #value = "SuperMarket" # not working
    if template.include? "DEER"
      value = "WRf"
    else
      value = "Warehouse"
    end
    num_units = 1

  when "Religious worship"
    if template.include? "DEER"
      value = "Asm"
    else
      value = "MediumOffice"
    end
    num_units = 1
    
  when "Retail other than mall"
    if template.include? "DEER"
      value = "RtS"
    else
      value = "RetailStandalone"
    end
    num_units = 1
    
  when "Service"
    if template.include? "DEER"
      value = "MLI"
    else
      value = "MediumOffice"
    end
    num_units = 1
    
  when "Single-Family"
    if template.include? "DEER"
      value = "MFm"
    else
      value = "MidriseApartment"
    end
    num_units = 1
    
  when "Strip shopping mall"
    if template.include? "DEER"
      value = "RtL"
    else
      value = "RetailStripmall"
    end
    num_units = 1
    
  when "Vacant"
    if template.include? "DEER"
      value = "SUn"
    else
      value = "Warehouse"
    end
    num_units = 1
    
  end
  
  return value, num_units
      
end

def map_tariff(value)
  # adds support for building type-specific tariffs

  case value
  
  when "Education",
    "Enclosed mall",
    "Food sales",
    "Food service",
    "Inpatient health care",
    "Laboratory",
    "Lodging",
    "Mixed use",
    "Strip shopping mall",
    "Nonrefrigerated warehouse",
    "Nursing",
    "Office",
    "Outpatient health care",
    "Public assembly",
    "Public order and safety",
    "Refrigerated warehouse",
    "Religious worship",
    "Retail other than mall",
    "Service"

    value = 'commercial'

  when "Mobile Home",
    "Multifamily (2 to 4 units)",
    "Multifamily (5 or more units)",
    "Single-Family",
    "Vacant"

    value = 'residential'
    
  end
  
  if value == 'commercial'
    value = 'sce_CI_TOU_8_B_less2kV'
  else
    value = 'sce_res_d'
  end

  return value
      
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
    @logger.warn("*** FLOOR AREA IS NIL... using footprint_area x #stories ***") if @logger
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
      
      # add tariff
      tariff_fn = map_tariff(value)
      result << {:measure_dir_name => 'apply_sce_tariffs', :argument => :tariff, :value => tariff_fn}

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

      # adjust standard based on year_built
      # ASHRAE:
      # 'DOE Ref Pre-1980'
      # 'DOE Ref 1980-2004'
      # '90.1-2004'
      # '90.1-2007'
      # '90.1-2010'
      # '90.1-2013'
      
      # DEER:
      # 'DEER 1985',
      # 'DEER 1996',
      # 'DEER 2003',
      # 'DEER 2007',
      # 'DEER 2011',
      # 'DEER 2014',
      # 'DEER 2015',
      # 'DEER 2017'

      # NREL ZNE Ready 2017

      the_val = value.to_i
      the_std = nil
      if template.include? "DEER"
        if the_val <= 1996
          the_std = 'DEER 1985'
        elsif the_val <= 2003
          the_std = 'DEER 1996'
        elsif the_val <= 2007  
          the_std = 'DEER 2003'
        elsif the_val <= 2011
          the_std = 'DEER 2007'
        elsif the_val <= 2014
          the_std = 'DEER 2011'
        elsif the_val <= 2015
          the_std = 'DEER 2014'
        elsif the_val <= 2017
          the_std = 'DEER 2015'
        else
          the std = 'DEER 2017'
        end        
      elsif template.include? "NREL ZNE Ready"
        # TODO: do anything about NREL ZNE Ready 2017?
      else
        # ASHRAE    
        if the_val < 1980
          the_std = 'DOE Ref Pre-1980'
        elsif the_val <= 2004
          the_std = 'DOE Ref 1980-2004'
        elsif the_val <= 2007
          the_std = '90.1-2004'
        elsif the_val <= 2010
          the_std = '90.1-2007'
        elsif the_val <= 2013
          the_std = '90.1-2010'
        else 
          the_std = '90.1-2013'
        end
      end  
      if !the_std.nil?
        @logger.info("**** OVERRIDING standard with year-built info, setting template to: #{the_std}")
        result << {:measure_dir_name => 'create_bar_from_building_type_ratios', :argument => :template, :value => the_std}
        result << {:measure_dir_name => 'create_typical_building_from_model_1', :argument => :template, :value => the_std}
        result << {:measure_dir_name => 'create_typical_building_from_model_2', :argument => :template, :value => the_std}
        result << {:measure_dir_name => 'swap_hvac_systems', :argument => :template, :value => the_std}
      end

      when :heating_vac
        next if value.nil?
        result << {:measure_dir_name => 'swap_hvac_systems', :argument => 'htg_src', :value => value}

      when :cooling_vac
        next if value.nil?
        result << {:measure_dir_name => 'swap_hvac_systems', :argument => 'clg_src', :value => value}

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