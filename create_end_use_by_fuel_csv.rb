require 'fileutils'
require 'openstudio'

# expects single argument with path to directory that contains dataoints
#path_datapoints = 'run/MyProject'
path_datapoints = ARGV[0]

# create CSV file
rows = []

# data to gather from results
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
keep << 'end_use_heating'
keep << 'end_use_cooling'
keep << 'end_use_interior_lighting'
keep << 'end_use_exterior_lighting'
keep << 'end_use_interior_equipment'
keep << 'end_use_exterior_equipment'
keep << 'end_use_fans'
keep << 'end_use_pumps'
keep << 'end_use_heat_rejection'
keep << 'end_use_humidification'
keep << 'end_use_heat_recovery'
keep << 'end_use_water_systems'
keep << 'end_use_refrigeration'
keep << 'end_use_generators'

# electric end use
keep << 'end_use_electricitiy_heating'
keep << 'end_use_electricitiy_cooling'
keep << 'end_use_electricitiy_interior_lighting'
keep << 'end_use_electricitiy_exterior_lighting'
keep << 'end_use_ielectricitiy_nterior_equipment'
keep << 'end_use_electricitiy_exterior_equipment'
keep << 'end_use_electricitiy_fans'
keep << 'end_use_electricitiy_pumps'
keep << 'end_use_electricitiy_heat_rejection'
keep << 'end_use_electricitiy_humidification'
keep << 'end_use_electricitiy_heat_recovery'
keep << 'end_use_electricitiy_water_systems'
keep << 'end_use_electricitiy_refrigeration'
keep << 'end_use_electricitiy_generators'

# gas end use
keep << 'end_use_natural_gas_heating'
keep << 'end_use_natural_gas_cooling'
keep << 'end_use_natural_gas_interior_lighting'
keep << 'end_use_natural_gas_exterior_lighting'
keep << 'end_use_natural_gas_interior_equipment'
keep << 'end_use_natural_gas_exterior_equipment'
keep << 'end_use_natural_gas_fans'
keep << 'end_use_natural_gas_pumps'
keep << 'end_use_natural_gas_heat_rejection'
keep << 'end_use_natural_gas_humidification'
keep << 'end_use_natural_gas_heat_recovery'
keep << 'end_use_natural_gas_water_systems'
keep << 'end_use_natural_gas_refrigeration'
keep << 'end_use_natural_gas_generators'

# variables ot keep from envelope_and_internal_load_breakdown
# heat gains
keep << 'electric_equipment_total_heating_energy_annual'
keep << 'gas_equipment_total_heating_energy_annual'
keep << 'zone_lights_total_heating_energy_annual'
keep << 'zone_people_sensible_heating_energy_annual'
keep << 'zone_mechanical_ventilation_cooling_load_increase_energy_annual'
keep << 'zone_infiltration_sensible_heat_gain_energy_annual'
keep << 'surface_window_heat_gain_energy_annual'
keep << 'ext_wall_heat_gain'
keep << 'ext_roof_heat_gain'
keep << 'ground_heat_gain'

# heat losses
keep << 'zone_infiltration_sensible_heat_loss_energy_annual'
keep << 'zone_mechanical_ventilation_heating_load_increase_energy_annual'
keep << 'surface_window_heat_loss_energy_annual'
keep << 'ext_wall_heat_loss'
keep << 'ext_roof_heat_loss'
keep << 'ground_heat_loss'

# scenario_mapping
# all measure through ViewModel with 1 not being "Skip"
scenario_mapping = {}
scenario_mapping['0 - Prototype-ChangeLocation'] =       [1,1,1,1,0,0,0,0,0,0,0,1]
scenario_mapping['1 - Prototype-NewHvac'] =              [1,1,1,1,0,0,0,0,0,0,1,1]
scenario_mapping['2 - Prototype-NewHvacLoadsConstSch'] = [1,1,1,1,0,0,1,0,0,0,1,1]
scenario_mapping['3a - Prototype-Bar-Sliced'] =          [1,1,1,1,1,0,1,0,0,0,1,1]
scenario_mapping['4a - Prototype-Bar-Blend'] =           [1,1,1,1,1,0,1,1,1,0,1,1]
scenario_mapping['3b - Typical-Bar-Sliced'] =            [1,0,1,1,0,1,1,0,0,0,1,1]
scenario_mapping['4b - Typical-Bar-Blend'] =             [1,0,1,1,0,1,1,1,1,0,1,1]
scenario_mapping['4c - Typical-Urban-Blend'] =           [1,0,1,1,0,1,1,1,0,1,1,1]
scenario_mapping['4d - Prototype-ProtoGeo-Blend'] =      [1,1,1,1,0,0,1,1,0,0,1,1]

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

  row_data[:building_name] = building_name
  row_data[:building_type] = building_type
  row_data[:city] = city

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

            # todo - see if temp_scenario_map matches any hash 
            row_data[:scenario] = scenario_mapping.key(temp_scenario_map)
      
            # todo change order of end uses to match Excel Spreadsheet

            result = measure_step.result.get
            result.stepValues.each do |arg|
              name = arg.name
              if keep.include?(name)
                # todo - add units to name
                column_name = name #"#{name}_#{arg.units.to_s}"
                row_data[column_name.to_sym] = arg.valueAsVariant.to_s
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

    # populate data
    rows << row_data

end

# populate and save CSV file
require "csv"
headers = []
rows.each {|hash| headers += hash.keys}
headers = headers.uniq

csv_rows = []
rows.each do |hash|
  arr_row = []
  headers.each {|header| arr_row.push(hash.key?(header) ? hash[header] : nil)}
  csv_row = CSV::Row.new(headers, arr_row)
  csv_rows.push(csv_row)
end
csv_table = CSV::Table.new(csv_rows)
path_report = "#{path_datapoints}/end_use_by_fuel.csv"
puts "saving csv file to #{path_report}"
File.open(path_report, 'w'){|file| file << csv_table.to_s}


