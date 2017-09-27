require 'fileutils'
require 'openstudio'

# expects single argument with path to directory that contains dataoints
#path_datapoints = 'run/MyProject'
path_datapoints = ARGV[0]

# create CSV file
rows = []

# todo - create a hash to contain all results data vs. simple CSV rows, do all error calculations 
# in ruby and export to CSV ready to plot graphs
features_hash = {}
features_hash['SecondarySchool'] = {}
features_hash['PrimarySchool'] = {}
features_hash['FullServiceRestaurant'] = {}
features_hash['QuickServiceRestaurant'] = {}
features_hash['SmallOffice'] = {}
features_hash['MediumOffice'] = {}
features_hash['LargeOffice'] = {}
features_hash['SmallHotel'] = {}
features_hash['LargeHotel'] = {}
features_hash['MidriseApartment'] = {}
features_hash['HighriseApartment'] = {}
features_hash['StripMall'] = {}
features_hash['Retail'] = {}
features_hash['Hospital'] = {}
features_hash['Outpatient'] = {}
features_hash['Warehouse'] = {}

# notes on has structure
# top level hash has key for each feature
# 2nd level hash for each feature has key for each scenario
# 3rd level hash for each sceario in each feature has key for each end use and other metric like heat gain breakdown

# data to gather from openstudio results
keep = []

# general info
keep << 'net_site_energy'
keep << 'total_building_area'
keep << 'eui'
keep << 'unmet_hours_during_heating'
keep << 'unmet_hours_during_cooling'
keep << 'unmet_hours_during_occupied_heating'
keep << 'unmet_hours_during_occupied_cooling'
keep << 'fuel_electricity'
keep << 'fuel_natural_gas'
keep << 'fuel_additional_fuel'
keep << 'fuel_district_cooling'
keep << 'fuel_district_heating'
keep << 'annual_peak_electric_demand'

# fuel independant end use
keep << 'end_use_interior_lighting'
keep << 'end_use_exterior_lighting'
keep << 'end_use_interior_equipment'
keep << 'end_use_exterior_equipment'
keep << 'end_use_water_systems'
keep << 'end_use_refrigeration'
keep << 'end_use_heating'
keep << 'end_use_cooling'
keep << 'end_use_fans'
keep << 'end_use_pumps'
keep << 'end_use_heat_rejection'
keep << 'end_use_humidification'
keep << 'end_use_heat_recovery'
keep << 'end_use_generators'

# error totals
keep << 'sum of end use errors as fraction of total consumpiton' # only used for error rows

# electric end use
keep << 'end_use_electricity_interior_lighting'
keep << 'end_use_electricity_exterior_lighting'
keep << 'end_use_electricity_interior_equipment'
keep << 'end_use_electricity_exterior_equipment'
keep << 'end_use_electricity_water_systems'
keep << 'end_use_electricity_refrigeration'
keep << 'end_use_electricity_heating'
keep << 'end_use_electricity_cooling'
keep << 'end_use_electricity_fans'
keep << 'end_use_electricity_pumps'
keep << 'end_use_electricity_heat_rejection'
keep << 'end_use_electricity_humidification'
keep << 'end_use_electricity_heat_recovery'
keep << 'end_use_electricity_generators'

# gas end use
keep << 'end_use_natural_gas_interior_lighting'
keep << 'end_use_natural_gas_exterior_lighting'
keep << 'end_use_natural_gas_interior_equipment'
keep << 'end_use_natural_gas_exterior_equipment'
keep << 'end_use_natural_gas_water_systems'
keep << 'end_use_natural_gas_refrigeration'
keep << 'end_use_natural_gas_heating'
keep << 'end_use_natural_gas_cooling'
keep << 'end_use_natural_gas_fans'
keep << 'end_use_natural_gas_pumps'
keep << 'end_use_natural_gas_heat_rejection'
keep << 'end_use_natural_gas_humidification'
keep << 'end_use_natural_gas_heat_recovery'
keep << 'end_use_natural_gas_generators'

# variables ot keep from envelope_and_internal_load_breakdown
keep2 = []

# heat gains
keep2 << 'zone_lights_total_heating_energy_annual'
keep2 << 'electric_equipment_total_heating_energy_annual'
keep2 << 'gas_equipment_total_heating_energy_annual'
keep2 << 'zone_people_sensible_heating_energy_annual'
keep2 << 'zone_mechanical_ventilation_cooling_load_increase_energy_annual'
keep2 << 'zone_infiltration_sensible_heat_gain_energy_annual'
keep2 << 'ground_heat_gain'
keep2 << 'ext_wall_heat_gain'
keep2 << 'surface_window_heat_gain_energy_annual'
keep2 << 'ext_roof_heat_gain'

# heat losses
keep2 << 'zone_infiltration_sensible_heat_loss_energy_annual'
keep2 << 'zone_mechanical_ventilation_heating_load_increase_energy_annual'
keep2 << 'ground_heat_loss'
keep2 << 'ext_wall_heat_loss'
keep2 << 'surface_window_heat_loss_energy_annual'
keep2 << 'ext_roof_heat_loss'

# scenario_mapping
# all measure through ViewModel with 1 not being "Skip"
scenario_mapping = {}
scenario_mapping['0 - Prototype'] =                      [1,1,1,1,0,0,0,0,0,0,0,1]
scenario_mapping['1 - Prototype-NewHvac'] =              [1,1,1,1,0,0,0,0,0,0,1,1]
scenario_mapping['2 - Prototype-NewHvacLoadsConstSch'] = [1,1,1,1,0,0,1,0,0,0,1,1]
#scenario_mapping['3a - Prototype-Bar-Sliced'] =          [1,1,1,1,1,0,1,0,0,0,1,1]
#scenario_mapping['4a - Prototype-Bar-Blend'] =           [1,1,1,1,1,0,1,1,1,0,1,1]
scenario_mapping['3b - Typical-Bar-Sliced'] =            [1,0,1,1,0,1,1,0,0,0,1,1]
scenario_mapping['4b - Typical-Bar-Blend'] =             [1,0,1,1,0,1,1,1,1,0,1,1]
scenario_mapping['4c - Typical-Urban-Blend'] =           [1,0,1,1,0,1,1,1,0,1,1,1]
scenario_mapping['4d - Prototype-Prototype-Blend'] =     [1,1,1,1,0,0,1,1,0,0,1,1]
scenario_mapping['-'] = nil #blank line for end of scenarios

# adding extra error scenarios that subtract one value from another
# key is an array of two scenarios
scenario_mapping[['0 - Prototype','1 - Prototype-NewHvac']] = nil
scenario_mapping[['1 - Prototype-NewHvac','2 - Prototype-NewHvacLoadsConstSch']] = nil
scenario_mapping[['2 - Prototype-NewHvacLoadsConstSch','3b - Typical-Bar-Sliced']] = nil
scenario_mapping[['2 - Prototype-NewHvacLoadsConstSch','4b - Typical-Bar-Blend']] = nil
scenario_mapping[['2 - Prototype-NewHvacLoadsConstSch','4c - Typical-Urban-Blend']] = nil
scenario_mapping[['2 - Prototype-NewHvacLoadsConstSch','4d - Prototype-Prototype-Blend']] = nil
scenario_mapping['--'] = nil #blank lines for end of error rows
scenario_mapping['---'] = nil #blank lines for end of error rows

# populate each feature with a scenario hash and stub out keys
features_hash.each do |feature,scenario_hash|
  scenario_mapping.each do |scenario_name,v2|
    scenario_hash[scenario_name] = {}
    # add in general values
      scenario_hash[scenario_name]['building_type'] = nil
      scenario_hash[scenario_name]['scenario'] = nil
      scenario_hash[scenario_name]['results_directory'] = nil
      scenario_hash[scenario_name]['city'] = nil
    # add in values from OpenStudio Results
    keep.each do |value_type|
      scenario_hash[scenario_name][value_type] = nil
    end
    # add in values for envelope and internal load breakdown
    keep2.each do |value_type|
      scenario_hash[scenario_name][value_type] = nil
    end
  end
end

# loop through resoruce files
results_directories = Dir.glob("#{path_datapoints}/*")
puts path_datapoints
results_directories.each do |results_directory|

  next if ! results_directory.include?("datapoint")
  row_data = {}
  row_data[:results_directory] = results_directory
  puts "working on #{results_directory}"

	# load the test model
	translator = OpenStudio::OSVersion::VersionTranslator.new
	path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{results_directory}/in.osm")

	model = translator.loadModel(path)
	next if not model.is_initialized
	model = model.get
  building_name = model.getBuilding.name.get
  city = model.getSite.weatherFile.get.city
  current_scenario = nil

  # remap building type as needed
  building_type = model.getBuilding.standardsBuildingType.get
  if building_type == "Office"
    if building_name.include?("Small")
      building_type = "SmallOffice"
    elsif building_name.include?("Medium")
      building_type = "MediumOffice"
    else
      building_type = "LargeOffice"
    end
  end
  if building_type == "RetailStandalone" then building_type = "Retail" end
  if building_type == "RetailStripmall" then building_type = "StripMall" end

	# load OSW to get information from argument values
    osw_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{results_directory}/out.osw")
    osw = OpenStudio::WorkflowJSON.load(osw_path).get
    runner = OpenStudio::Measure::OSRunner.new(osw)
    runner.workflow.workflowSteps.each do |step|
      if step.to_MeasureStep.is_initialized
        measure_step = step.to_MeasureStep.get
       	measure_dir_name = measure_step.measureDirName

        if measure_step.name.is_initialized

          measure_step_name = measure_step.name.get.downcase.gsub(" ","_")
          next if ! measure_step.result.is_initialized
          next if ! measure_step.result.get.stepResult.is_initialized
          measure_step_result = measure_step.result.get.stepResult.get.valueName
          row_data[measure_step_name.to_sym] = measure_step_result

          if measure_step_name == "openstudio_results"

            # by looking at what is skipped, add column for scenario lookup
            # todo - confirm I got symbols correct
            temp_scenario_map = []
            if row_data[:gem_env_report] == 'Skip' then temp_scenario_map << 0 else temp_scenario_map << 1 end
            if row_data[:create_doe_prototype_building] == 'Skip' then temp_scenario_map << 0  elsif row_data[:create_doe_prototype_building] == 'Success' then temp_scenario_map << 1 else temp_scenario_map << 1 end
            if row_data[:set_run_period] == 'Skip' then temp_scenario_map << 0  else temp_scenario_map << 1 end
            if row_data[:changebuildinglocation] == 'Skip' then temp_scenario_map << 0  else temp_scenario_map << 1 end
            if row_data[:create_bar_from_model_1] == 'Skip' then temp_scenario_map << 0  else temp_scenario_map << 1 end
            if row_data[:create_bar_from_building_type_ratios] == 'Skip' then temp_scenario_map << 0  else temp_scenario_map << 1 end
            if row_data[:create_typical_building_from_model_1] == 'Skip' then temp_scenario_map << 0  else temp_scenario_map << 1 end
            if row_data[:blended_space_type_from_model] == 'Skip' then temp_scenario_map << 0  else temp_scenario_map << 1 end
            if row_data[:create_bar_from_model_2] == 'Skip' then temp_scenario_map << 0  else temp_scenario_map << 1 end
            if row_data[:urban_geometry_creation] == 'Skip' then temp_scenario_map << 0  else temp_scenario_map << 1 end
            if row_data[:create_typical_building_from_model_2] == 'Skip' then temp_scenario_map << 0  else temp_scenario_map << 1 end
            if row_data[:viewmodel] == 'Skip' then temp_scenario_map << 0 else temp_scenario_map << 1 end

            #see if temp_scenario_map matches any hash 
            current_scenario = scenario_mapping.key(temp_scenario_map) 
            next if current_scenario.nil?

            # populate feature_hash
            features_hash[building_type][current_scenario]['building_type'] = building_type
            features_hash[building_type][current_scenario]['scenario'] = current_scenario
            features_hash[building_type][current_scenario]['results_directory'] = results_directory
            features_hash[building_type][current_scenario]['city'] = city

            # populate registerValue objects
            result = measure_step.result.get
            result.stepValues.each do |arg|
              name = arg.name
              if keep.include?(name)
                # todo - add units to name
                column_name = name #"#{name}_#{arg.units.to_s}"

                # populate feature_hash
                features_hash[building_type][current_scenario][column_name] = arg.valueAsVariant.to_s
              end
            end

          elsif measure_step_name == "envelope_and_internal_load_breakdown"

            # populate registerValue objects
            result = measure_step.result.get
            result.stepValues.each do |arg|
              name = arg.name
              if keep2.include?(name)
                # todo - add units to name
                column_name = name #"#{name}_#{arg.units.to_s}"

                # populate feature_hash
                  next if current_scenario.nil?
                features_hash[building_type][current_scenario][column_name] = arg.valueAsVariant.to_s
              end
            end

          end

        end

        if measure_step.result.is_initialized
          result = measure_step.result.get
        else
          puts "No result for #{measure_dir_name}"
        end
      else
        #puts "This step is not a measure"
      end

    end

end

# todo - post process features_hash to calculate error metrics. 
features_hash.each do |feature,scenario_hash|
  building_type = nil
  scenario_hash.each do |scenario,value_hash|
    if building_type.nil?
      building_type = value_hash['building_type']
    end
    next if not scenario.is_a?(Array)
    next if building_type.nil?

    # populate general information
    features_hash[building_type][scenario]['scenario'] = scenario.join("|")   
    features_hash[building_type][scenario]['building_type'] = building_type
    features_hash[building_type][scenario]['city'] = features_hash[building_type][scenario.first]['city']

    # store consumption for error calculation
    total_consumption = features_hash[building_type][scenario.first]['net_site_energy'].to_f

    # populate end use columns
    sum_of_abs_end_use_errors = nil
    features_hash[building_type][scenario.first].each do |key,value|
      next if ['building_type','scenario','results_directory','city'].include?(key) # skip first few non double columns alrady addressed below
      if value.nil?
        features_hash[building_type][scenario][key] = nil
      else
        features_hash[building_type][scenario][key] = (value.to_f - features_hash[building_type][scenario.last][key].to_f).abs
      end

      # udpate end use value
      next if not key.include?('end_use')
      next if key.include?('end_use_electricity')
      next if key.include?('end_use_natural')

      # divide delta by consumption of first scenario
      raw_end_use_error = (value.to_f - features_hash[building_type][scenario.last][key].to_f).abs/total_consumption
      features_hash[building_type][scenario][key] = "#{100*raw_end_use_error}%"

      if sum_of_abs_end_use_errors.nil?
        sum_of_abs_end_use_errors = raw_end_use_error
      else
        sum_of_abs_end_use_errors += raw_end_use_error
      end

    end

    # populate sum of absolute values for end use errors
    if total_consumption > 0
      features_hash[building_type][scenario]['sum of end use errors as fraction of total consumpiton'] = "#{100*sum_of_abs_end_use_errors}%"
    end

  end
end

# populate and save CSV file
require "csv"
headers = []
# looping through this to keep keys in the order they were entered
features_hash.values.first.values.first.each do |k,v|
  headers << k
end
csv_rows = []
features_hash.each do |feature,scenario_hash|
  scenario_hash.each do |scenario,value_hash|
    arr_row = []
    headers.each {|header| arr_row.push(value_hash.key?(header) ? value_hash[header] : nil)}
    csv_row = CSV::Row.new(headers, arr_row)
    csv_rows.push(csv_row)    
  end
end

csv_table = CSV::Table.new(csv_rows)
path_report = "#{path_datapoints}/end_use_by_fuel.csv"
puts "saving csv file to #{path_report}"
File.open(path_report, 'w'){|file| file << csv_table.to_s}




