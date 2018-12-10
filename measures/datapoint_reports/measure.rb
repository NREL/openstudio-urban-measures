######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

require 'json'
require 'net/http'

#start the measure
class DatapointReports < OpenStudio::Measure::ReportingMeasure

  # human readable name
  def name
    return "DatapointReports"
  end

  # human readable description
  def description
    return "Updates Datapoint in CityDB with simulation results"
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments()
    args = OpenStudio::Measure::OSArgumentVector.new
    
    # url of the city database
    city_db_url = OpenStudio::Ruleset::OSArgument.makeStringArgument("city_db_url", true)
    city_db_url.setDisplayName("City Database Url")
    city_db_url.setDescription("Url of the City Database")
    city_db_url.setDefaultValue("")
    args << city_db_url
        
    # project id to update
    project_id = OpenStudio::Ruleset::OSArgument.makeStringArgument("project_id", true)
    project_id.setDisplayName("Project ID")
    project_id.setDescription("Project ID to generate reports for.")
    project_id.setDefaultValue('0')
    args << project_id
    
    # datapoint id to update
    datapoint_id = OpenStudio::Ruleset::OSArgument.makeStringArgument("datapoint_id", true)
    datapoint_id.setDisplayName("Datapoint ID")
    datapoint_id.setDescription("Datapoint ID to generate reports for.")
    datapoint_id.setDefaultValue('0')
    args << datapoint_id
    
    return args
  end 
  
  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)
    
    result = OpenStudio::IdfObjectVector.new
    
    # use the built-in error checking 
    if !runner.validateUserArguments(arguments(), user_arguments)
      return result
    end
    
    result << OpenStudio::IdfObject.load("Output:Meter:MeterFileOnly,Electricity:Facility,Timestep;").get
    result << OpenStudio::IdfObject.load("Output:Meter:MeterFileOnly,ElectricityProduced:Facility,Timestep;").get
    result << OpenStudio::IdfObject.load("Output:Meter:MeterFileOnly,Gas:Facility,Timestep;").get

    timeseries = ["District Cooling Chilled Water Rate", "District Cooling Mass Flow Rate", 
                  "District Cooling Inlet Temperature", "District Cooling Outlet Temperature", 
                  "District Heating Hot Water Rate", "District Heating Mass Flow Rate", 
                  "District Heating Inlet Temperature", "District Heating Outlet Temperature"]

    timeseries.each do |ts|
      result << OpenStudio::IdfObject.load("Output:Variable,*,#{ts},Timestep;").get
    end
    
    return result
  end

  #short_os_fuel method
  def short_os_fuel(fuel_string)
    val = nil
    fuel_vec = fuel_string.split(" ")
    if fuel_vec[0] == "Electricity"
      val = "Elec"
    elsif fuel_vec[0] == "District"
      fuel_vec[1] == "Heating" ? val = "Dist Heat" : val = "Dist Cool"
    elsif fuel_vec[0] == "Natural"
      val = "NG"
    elsif fuel_vec[0] == "Additional"
      val = "Other Fuel"
    elsif fuel_vec[0] == "Water"
      val = "Water"
    else
      val = "Unknown"
    end

    val

  end

  #short_os_cat method
  def short_os_cat(category_string)
    val = nil
    cat_vec = category_string.split(" ")
    if cat_vec[0] == "Heating"
      val = "Heat"
    elsif cat_vec[0] == "Cooling"
      val = "Cool"
    elsif cat_vec[0] == "Humidification"
      val = "Humid"
    elsif cat_vec[0] == "Interior"
      cat_vec[1] == "Lighting" ? val = "Int Light" : val = "Int Equip"
    elsif cat_vec[0] == "Exterior"
      cat_vec[1] == "Lighting" ? val = "Ext Light" : val = "Ext Equip"
    elsif cat_vec[0] == "Heat"
      cat_vec[1] == "Recovery" ? val = "Heat Rec" : val = "Heat Rej"
    elsif cat_vec[0] == "Pumps"
      val = "Pumps"
    elsif cat_vec[0] == "Fans"
      val = "Fans"
    elsif cat_vec[0] == "Refrigeration"
      val = "Rfg"
    elsif cat_vec[0] == "Generators"
      val = "Gen"
    elsif cat_vec[0] == "Water"
      val = "Water Systems"
    else
      val = "Unknown"
    end

    val

  end

  #sql_query method
  def sql_query(runner, sql, report_name, query)
    val = nil
    result = sql.execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='#{report_name}' AND #{query}")
    if result.empty?
      runner.registerWarning("Query failed for #{report_name} and #{query}")
    else
      begin
        val = result.get
      rescue
        val = nil
        runner.registerWarning("Query result.get failed")
      end
    end

    val
  end
  
  def add_result(results, name, value, units, units_from = nil)

    # apply unit conversion
    if not units_from.nil?
      value_converted = OpenStudio::convert(value,units_from,units)
      if value_converted.is_initialized
        value = value_converted.get
      else
        @runner.registerWarning("Was not able to register value for #{name} with value of #{value} #{units_from} converted to #{units}.")
      end
    end

    # register value
    if !value.to_f.nan? and !value.to_f.infinite?
      results[name] = value
      results[name + '_units'] = units
      if name.nil?
        @runner.registerWarning("Name is nil")
      elsif value.nil?
        @runner.registerWarning("Value for '#{name}' is nil")
      elsif units.nil?
        @runner.registerValue(name, value)
      else
        @runner.registerValue(name, value, units)
      end
    end
  end

   def to_displayTime( os_time )
    js_time = os_time.to_s
    # Replace the '-' with '/'
    js_time = js_time.gsub('-','/')
    # Replace month abbreviations with numbers
    js_time = js_time.gsub('Jan','01')
    js_time = js_time.gsub('Feb','02')
    js_time = js_time.gsub('Mar','03')
    js_time = js_time.gsub('Apr','04')
    js_time = js_time.gsub('May','05')
    js_time = js_time.gsub('Jun','06')
    js_time = js_time.gsub('Jul','07')
    js_time = js_time.gsub('Aug','08')
    js_time = js_time.gsub('Sep','09')
    js_time = js_time.gsub('Oct','10')
    js_time = js_time.gsub('Nov','11')
    js_time = js_time.gsub('Dec','12')
    # Remove year
    js_time.slice!(0,5)
    return js_time
  end

  def get_datapoint(project_id, datapoint_id)
    http = Net::HTTP.new(@city_db_url, @port)
    http.read_timeout = 1000
    if @city_db_is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    
    request = Net::HTTP::Get.new("/api/retrieve_datapoint.json?project_id=#{project_id}&datapoint_id=#{datapoint_id}")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])
  
    response = http.request(request)
    if  response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      @result = false
    end

    datapoint = JSON.parse(response.body, :symbolize_names => true)[:datapoint]
      
    return datapoint
  end

  #define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    #use the built-in error checking
    unless runner.validateUserArguments(arguments, user_arguments)
      return false
    end
    
    # use the built-in error checking 
    if !runner.validateUserArguments(arguments(), user_arguments)
      return false
    end
    
    city_db_url = runner.getStringArgumentValue("city_db_url", user_arguments)
    project_id = runner.getStringArgumentValue("project_id", user_arguments)
    datapoint_id = runner.getStringArgumentValue("datapoint_id", user_arguments)
    
    uri = URI.parse(city_db_url)
    @city_db_is_https = uri.scheme == 'https' ? true : false
    @city_db_url = uri.host
    @port = uri.port
    
    @runner = runner
    
    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get

    sql_file = runner.lastEnergyPlusSqlFile
    if sql_file.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sql_file = sql_file.get
    model.setSqlFile(sql_file)
  
    # this is the datapoint hash that will be posted to the insight center
    results = {}

    #get building footprint to use for calculating end use EUIs
    building_area = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Building Area' AND RowName='Total Building Area' AND ColumnName='Area'")
    add_result(results, 'building_area', building_area, 'ft^2', 'm^2')
    
    #get end use totals for fuels
    site_energy_use = 0.0
    OpenStudio::EndUseFuelType.getValues.each do |fuel_type|
      fuel_str = OpenStudio::EndUseFuelType.new(fuel_type).valueDescription
      fuel_type_aggregation = 0.0
      mult_factor = 1
      if fuel_str != "Water"
        runner_units_eui_to = "kBtu/ft^2"
        runner_units_eui = "MJ/m^2"
        metadata_units_eui = "megajoules_per_square_meter"
        mult_factor = 1000
        runner_units_agg_to = "kBtu"
        runner_units_agg = "GJ"
        metadata_units_agg = "gigajoule"
      else
        runner_units_eui_to = "ft"
        runner_units_eui = "m"
        metadata_units_eui = "meter"
        runner_units_agg_to = "ft^3"
        runner_units_agg = "m^3"
        metadata_units_agg = "cubic meter"
      end
      OpenStudio::EndUseCategoryType.getValues.each do |category_type|
        category_str = OpenStudio::EndUseCategoryType.new(category_type).valueDescription
        temp_val = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='End Uses' AND RowName='#{category_str}' AND ColumnName='#{fuel_str}'")
        if temp_val
          eui_val = temp_val / building_area * mult_factor
          prefix_str = OpenStudio::toUnderscoreCase("#{fuel_str}_#{category_str}_eui")
          add_result(results, prefix_str, eui_val, runner_units_eui_to, runner_units_eui)
          short_name = "#{short_os_fuel(fuel_str)} #{short_os_cat(category_str)} EUI"
          fuel_type_aggregation += temp_val
        end
      end
      if fuel_type_aggregation
        prefix_str = OpenStudio::toUnderscoreCase("total_#{fuel_str}_end_use")
        add_result(results, prefix_str, fuel_type_aggregation, runner_units_agg_to, runner_units_agg)
        short_name = "#{short_os_fuel(fuel_str)} Total"
        site_energy_use += fuel_type_aggregation if fuel_str != "Water"
      end

      if fuel_type == 'Electricity'
        unit_str = 'kW'

      end
    end

    add_result(results, 'site_energy_use', site_energy_use, "kBtu", "GJ")

    #get monthly fuel aggregates
    #todo: get all monthly fuel type outputs, including non-present fuel types, mapping to 0
    OpenStudio::EndUseFuelType.getValues.each do |fuel_type|
      fuel_str = OpenStudio::EndUseFuelType.new(fuel_type).valueDescription
      mult_factor = 10**-6 / building_area
      runner_units_to = "kBtu/ft^2"
      runner_units = "MJ/m^2"
      metadata_units = "megajoules_per_square_meter"
      if fuel_str == "Water"
        next
      end

      demand_aggregation = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
      OpenStudio::MonthOfYear.getValues.each do |month|
        if month >= 1 and month <= 12
          fuel_and_month_aggregation = 0.0
          
          OpenStudio::EndUseCategoryType::getValues.each do |category_type|
            if sql_file.energyConsumptionByMonth(OpenStudio::EndUseFuelType.new(fuel_str), OpenStudio::EndUseCategoryType.new(category_type), OpenStudio::MonthOfYear.new(month)).is_initialized
              val_in_j = sql_file.energyConsumptionByMonth(OpenStudio::EndUseFuelType.new(fuel_str), OpenStudio::EndUseCategoryType.new(category_type), OpenStudio::MonthOfYear.new(month)).get
              fuel_and_month_aggregation += val_in_j
            end

            if fuel_str == 'Electricity'
              if !sql_file.peakEnergyDemandByMonth(OpenStudio::EndUseFuelType.new(fuel_type),
                                                OpenStudio::EndUseCategoryType.new(category_type),
                                                OpenStudio::MonthOfYear.new(month)).empty?
                valInJ = sql_file.peakEnergyDemandByMonth(OpenStudio::EndUseFuelType.new(fuel_type),
                                                       OpenStudio::EndUseCategoryType.new(category_type),
                                                       OpenStudio::MonthOfYear.new(month)).get
                valInUnits = OpenStudio.convert(valInJ, 'W', 'kW').get
                demand_aggregation[(month-1)] += valInUnits
                #runner.registerInfo("#DEMAND AGGREGATION: #{demand_aggregation}")
              end
            end
          end
          fuel_and_month_aggregation *= mult_factor
          month_str = OpenStudio::MonthOfYear.new(month).valueDescription
          prefix_str = OpenStudio::toUnderscoreCase("#{month_str}_end_use_#{fuel_str}_eui")
          add_result(results, prefix_str, fuel_and_month_aggregation, runner_units_to, runner_units)
          short_name = "#{month_str[0..2]} #{short_os_fuel(fuel_str)} EUI"
        end
      end

      if fuel_str == 'Electricity'
        # for monthly peak demand
        runner.registerInfo("fuel_type: #{fuel_type}, fuel_str: #{fuel_str}")
        demand_aggregation.each_with_index do |v, k|
          #runner.registerInfo("K: #{k}, v: #{v}")
          month_str = OpenStudio::MonthOfYear.new(k+1).valueDescription
          prefix_str = OpenStudio::toUnderscoreCase("#{month_str}_peak_demand")
          add_result(results, prefix_str, v, 'kW')
        end
      end
      
    end

    # queries that don't have API methods yet

    life_cycle_cost = sql_query(runner, sql_file, "Life-Cycle Cost Report", "TableName='Present Value by Category' AND RowName='Grand Total' AND ColumnName='Present Value'")
    add_result(results, "life_cycle_cost", life_cycle_cost, "dollars")
  
    conditioned_area = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Building Area' AND RowName='Net Conditioned Building Area' AND ColumnName='Area'")
    add_result(results, "conditioned_area", conditioned_area, "ft^2", "m^2")

    unconditioned_area = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Building Area' AND RowName='Unconditioned Building Area' AND ColumnName='Area'")
    add_result(results, "unconditioned_area", unconditioned_area, "ft^2", "m^2")
    
    total_site_energy = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Site and Source Energy' AND RowName='Total Site Energy' AND ColumnName='Total Energy'")
    add_result(results, "total_site_energy", total_site_energy, "kBtu", "GJ")
    
    net_site_energy = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Site and Source Energy' AND RowName='Net Site Energy' AND ColumnName='Total Energy'")
    add_result(results, "net_site_energy", net_site_energy, "kBtu", "GJ")
    
    total_source_energy = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Site and Source Energy' AND RowName='Total Source Energy' AND ColumnName='Total Energy'")
    add_result(results, "total_source_energy", total_source_energy, "kBtu", "GJ")
    
    net_source_energy = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Site and Source Energy' AND RowName='Net Source Energy' AND ColumnName='Total Energy'")
    add_result(results, "net_source_energy", net_source_energy, "kBtu", "GJ")
    
    total_site_eui = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Site and Source Energy' AND RowName='Total Site Energy' AND ColumnName='Energy Per Conditioned Building Area'")
    add_result(results, "total_site_eui", total_site_eui, "kBtu/ft^2", "MJ/m^2")

    total_source_eui = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Site and Source Energy' AND RowName='Total Source Energy' AND ColumnName='Energy Per Conditioned Building Area'")
    add_result(results, "total_source_eui", total_source_eui, "kBtu/ft^2", "MJ/m^2")

    net_site_eui = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Site and Source Energy' AND RowName='Net Site Energy' AND ColumnName='Energy Per Conditioned Building Area'")
    add_result(results, "net_site_eui", net_site_eui, "kBtu/ft^2", "MJ/m^2")

    net_source_eui = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Site and Source Energy' AND RowName='Net Source Energy' AND ColumnName='Energy Per Conditioned Building Area'")
    add_result(results, "net_source_eui", net_source_eui, "kBtu/ft^2", "MJ/m^2")

    time_setpoint_not_met_during_occupied_heating = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Heating' AND ColumnName='Facility'")
    add_result(results, "time_setpoint_not_met_during_occupied_heating", time_setpoint_not_met_during_occupied_heating, "hr")

    time_setpoint_not_met_during_occupied_cooling = sql_query(runner, sql_file, "AnnualBuildingUtilityPerformanceSummary", "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Cooling' AND ColumnName='Facility'")
    add_result(results, "time_setpoint_not_met_during_occupied_cooling", time_setpoint_not_met_during_occupied_cooling, "hr")

    time_setpoint_not_met_during_occupied_hours = time_setpoint_not_met_during_occupied_heating + time_setpoint_not_met_during_occupied_cooling
    add_result(results, "time_setpoint_not_met_during_occupied_hours", time_setpoint_not_met_during_occupied_hours, "hr")

    window_to_wall_ratio_north = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='Window-Wall Ratio' AND RowName='Gross Window-Wall Ratio' AND ColumnName='North (315 to 45 deg)'")
    add_result(results, "window_to_wall_ratio_north", window_to_wall_ratio_north, "%")

    window_to_wall_ratio_south = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='Window-Wall Ratio' AND RowName='Gross Window-Wall Ratio' AND ColumnName='South (135 to 225 deg)'")
    add_result(results, "window_to_wall_ratio_south", window_to_wall_ratio_south, "%")

    window_to_wall_ratio_east = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='Window-Wall Ratio' AND RowName='Gross Window-Wall Ratio' AND ColumnName='East (45 to 135 deg)'")
    add_result(results, "window_to_wall_ratio_east", window_to_wall_ratio_east, "%")

    window_to_wall_ratio_west = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='Window-Wall Ratio' AND RowName='Gross Window-Wall Ratio' AND ColumnName='West (225 to 315 deg)'")
    add_result(results, "window_to_wall_ratio_west", window_to_wall_ratio_west, "%")

    lat = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='General' AND RowName='Latitude' AND ColumnName='Value'")
    add_result(results, "latitude", lat, "deg")

    long = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='General' AND RowName='Longitude' AND ColumnName='Value'")
    add_result(results, "longitude", long, "deg")

    elev = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='General' AND RowName='Elevation' AND ColumnName='Value'")
    add_result(results, "elevation", elev, "ft", "m")

    weather_file = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='General' AND RowName='Weather File' AND ColumnName='Value'")
    add_result(results, "weather_file", weather_file, "deg")

    energy_cost_total = sql_query(runner, sql_file, "LEEDsummary", "TableName='EAp2-7. Energy Cost Summary' AND RowName='Total' AND ColumnName='Total Energy Cost'")
    add_result(results, "energy_cost_total", energy_cost_total, "$")

    energy_cost_electricity = sql_query(runner, sql_file, "LEEDsummary", "TableName='EAp2-7. Energy Cost Summary' AND RowName='Electricity' AND ColumnName='Total Energy Cost'")
    add_result(results, "energy_cost_electricity", energy_cost_electricity, "$")

    energy_cost_natural_gas = sql_query(runner, sql_file, "LEEDsummary", "TableName='EAp2-7. Energy Cost Summary' AND RowName='Natural Gas' AND ColumnName='Total Energy Cost'")
    add_result(results, "energy_cost_natural_gas", energy_cost_natural_gas, "$")

    energy_cost_other = sql_query(runner, sql_file, "LEEDsummary", "TableName='EAp2-7. Energy Cost Summary' AND RowName='Other' AND ColumnName='Total Energy Cost'")
    add_result(results, "energy_cost_other", energy_cost_other, "$")
    
    # building_name = sql_query(runner, sql_file, "Initializationsummary", "TableName='Building Information' AND RowName='1' AND ColumnName='Building Name'")
    # add_result(results, "building_name", building_name.to_s,building_name.to_s)


    # queries with one-line API methods
    
    timesteps_per_hour = model.getTimestep.numberOfTimestepsPerHour
    add_result(results, "timesteps_per_hour", timesteps_per_hour, "")
    
    begin_month = model.getRunPeriod.getBeginMonth
    add_result(results, "begin_month", begin_month, "")
    
    begin_day_of_month = model.getRunPeriod.getBeginDayOfMonth
    add_result(results, "begin_day_of_month", begin_day_of_month, "")
    
    end_month = model.getRunPeriod.getEndMonth
    add_result(results, "end_month", end_month, "")
    
    end_day_of_month = model.getRunPeriod.getEndDayOfMonth
    add_result(results, "end_day_of_month", end_day_of_month, "")
    
    begin_year = model.getYearDescription.calendarYear
    if begin_year.is_initialized
      add_result(results, "begin_year", begin_year.get, "")
    end
    
    building = model.getBuilding
    
    building_rotation = building.northAxis
    add_result(results, "orientation", building_rotation, "deg")

    total_occupancy = building.numberOfPeople
    num_units = 1
    if building.standardsNumberOfLivingUnits.is_initialized
      num_units = building.standardsNumberOfLivingUnits.get.to_i
    end
    add_result(results, "total_occupancy", total_occupancy * num_units, "people")

    occupancy_density = building.peoplePerFloorArea
    add_result(results, "occupant_density", occupancy_density, "people/ft^2", "people/m^2")

    lighting_power = building.lightingPower
    add_result(results, "lighting_power", lighting_power, "W")

    lighting_power_density = building.lightingPowerPerFloorArea
    add_result(results, "lighting_power_density", lighting_power_density, "W/ft^2", "W/m^2")

    infiltration_rate = building.infiltrationDesignAirChangesPerHour
    add_result(results, "infiltration_rate", infiltration_rate, "ACH")

    number_of_floors = building.standardsNumberOfStories.get if building.standardsNumberOfStories.is_initialized
    number_of_floors ||= nil
    add_result(results, "number_of_floors", number_of_floors, "")

    building_type = building.standardsBuildingType.to_s if building.standardsBuildingType.is_initialized
    building_type ||= nil
    add_result(results, "building_type", building_type, "")

    building_name = model.getBuilding.name.to_s
    add_result(results, "building_name", building_name, "")

    #get exterior wall, exterior roof, and ground plate areas
    exterior_wall_area = 0.0
    exterior_roof_area = 0.0
    ground_contact_area = 0.0
    surfaces = model.getSurfaces
    surfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Outdoors" and surface.surfaceType == "Wall"
        exterior_wall_area += surface.netArea
      end
      if surface.outsideBoundaryCondition == "Outdoors" and surface.surfaceType == "RoofCeiling"
        exterior_roof_area += surface.netArea
      end
      if surface.outsideBoundaryCondition == "Ground" and surface.surfaceType == "Floor"
        ground_contact_area += surface.netArea
      end
    end

    add_result(results, "exterior_wall_area", exterior_wall_area, "ft^2", "m^2")

    add_result(results, "exterior_roof_area", exterior_roof_area, "ft^2", "m^2")

    add_result(results, "ground_contact_area", ground_contact_area, "ft^2", "m^2")

    #get exterior fenestration area
    exterior_fenestration_area = 0.0
    subsurfaces = model.getSubSurfaces
    subsurfaces.each do |subsurface|
      if subsurface.outsideBoundaryCondition == "Outdoors"
        if subsurface.subSurfaceType == "FixedWindow" or subsurface.subSurfaceType == "OperableWindow"
          exterior_fenestration_area += subsurface.netArea
        end
      end
    end

    add_result(results, "exterior_fenestration_area", exterior_fenestration_area, "ft^2", "m^2")

    #get density of economizers in airloops
    num_airloops = 0
    num_economizers = 0
    model.getAirLoopHVACs.each do |air_loop|
      num_airloops += 1
      if air_loop.airLoopHVACOutdoorAirSystem.is_initialized
        air_loop_oa = air_loop.airLoopHVACOutdoorAirSystem.get
        air_loop_oa_controller = air_loop_oa.getControllerOutdoorAir
        if air_loop_oa_controller.getEconomizerControlType != "NoEconomizer"
          num_economizers += 1
        end
      end
    end
    economizer_density = num_economizers / num_airloops if num_airloops != 0
    economizer_density ||= nil

    add_result(results, "economizer_density", economizer_density, "")

    #get aspect ratios
    north_wall_area = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='Window-Wall Ratio' AND RowName='Gross Wall Area' AND ColumnName='North (315 to 45 deg)'")
    east_wall_area = sql_query(runner, sql_file, "InputVerificationandResultsSummary", "TableName='Window-Wall Ratio' AND RowName='Gross Wall Area' AND ColumnName='East (45 to 135 deg)'")
    aspect_ratio = north_wall_area / east_wall_area if north_wall_area != 0 && east_wall_area != 0
    aspect_ratio ||= nil

    add_result(results, "aspect_ratio", aspect_ratio, "")

    # KAF special transformer data
    # get datapoint to see if it's a transformer
    name_plate_rating = nil
    isTransformerFlag = false
    dp = get_datapoint(project_id, datapoint_id)
    # if so, do some extra stuff
    if dp[:feature_type] == 'District System' && dp[:district_system_type] && (dp[:district_system_type] == 'Transformer' || dp[:district_system_type] == 'Transformer with Storage')
      isTransformerFlag = true
    end

    
    # get timeseries
    timeseries = ["Electricity:Facility", "ElectricityProduced:Facility", "Gas:Facility", "DistrictCooling:Facility", "DistrictHeating:Facility", 
                  "District Cooling Chilled Water Rate", "District Cooling Mass Flow Rate", "District Cooling Inlet Temperature", "District Cooling Outlet Temperature", 
                  "District Heating Hot Water Rate", "District Heating Mass Flow Rate", "District Heating Inlet Temperature", "District Heating Outlet Temperature"]        

    # add additional thermal comfort timeseries            
    comfortTimeseries = ["Zone Thermal Comfort Fanger Model PMV", "Zone Thermal Comfort Fanger Model PPD", "Zone Thermal Comfort ASHRAE 55 Simple Model Summer Clothes Not Comfortable Time",
                  "Zone Thermal Comfort ASHRAE 55 Simple Model Winter Clothes Not Comfortable Time", "Zone Thermal Comfort ASHRAE 55 Simple Model Summer or Winter Clothes Not Comfortable Time"]  
    timeseries += comfortTimeseries

    # add additional power timeseries (for calculating transformer apparent power to compare to rating ) in VA
    powerTimeseries = ["Net Electric Energy", "Electricity:Facility Power", "ElectricityProduced:Facility Power", "Electricity:Facility Apparent Power", "ElectricityProduced:Facility Apparent Power", "Net Power", "Net Apparent Power"]
    timeseries += powerTimeseries
    runner.registerInfo("All timeseries: #{timeseries}")
    tsToKeep = ["Electricity:Facility", "ElectricityProduced:Facility"]
    tsToKeepIndexes = {}

    # use power_factor from datapoint, otherwise default to 0.9
    # TODO: have default based on building type
    powerFactor = dp[:power_factor].nil? ? 0.9 : dp[:power_factor]

    if isTransformerFlag
      # These are net energy and power
      transformerTimeseries = [
              "Transformer Distribution Electric Loss Energy", 
              "Transformer Output Electric Energy", 
              "Transformer Input Electric Energy", 
              "Transformer Output Electric Power", 
              "Transformer Input Electric Power", 
              "Schedule Value"]

      # SPECIAL CASE: transformer with battery, report out Additional timeseries   
      if dp[:district_system_type] == 'Transformer with Storage'
        storageTimeseries = [
          'Electric Storage Charge Energy',
          'Electric Storage Charge Power',
          'Electric Storage Simple Charge State',
          'Electric Storage Discharge Power',
          'Electric Storage Discharge Energy',
          'Electric Load Center Requested Electric Power',
          'Electric Load Center Produced Electric Power',
          'Electric Load Center Produced Electric Energy'
        ]
        transformerTimeseries += storageTimeseries
      end

      # Only do transformer timeseries for transformers (skip the others as they don't really make sense)
      timeseries = transformerTimeseries
     
      # get workspace and transformer rating
      workspace = runner.lastEnergyPlusWorkspace
      if workspace.empty?
        runner.registerError('Cannot find last idf file.')
        return false
      end
      workspace = workspace.get

      workspace.getObjectsByType("ElectricLoadCenter:Transformer".to_IddObjectType).each do |object|
        name = object.nameString
        name_plate_rating = object.getDouble(5,true)
        if name_plate_rating.is_initialized
          name_plate_rating = name_plate_rating.get
          runner.registerInfo("#{name} has nameplate rating of #{name_plate_rating} VA")
        end
      end
    end
   
    n = nil
    values = []
    tmpArray = []
    # Since schedule value will have a bunch of key_values, we need to keep track of these as additional timeseries
    key_cnt = 0
    new_timeseries = []
    timeseries.each_index do |i|    
      timeseries_name = timeseries[i]
      runner.registerInfo("TIMESERIES: #{timeseries_name}")

      key_values = sql_file.availableKeyValues("RUN PERIOD 1", "Zone Timestep", timeseries_name)
      runner.registerInfo("KEY VALUES: #{key_values}")
      if key_values.empty?
        key_values = [""]
      # else
      #   key_values = key_values[0]
      end
      
      # get seconds to convert J to W  (J/sec = W)
      power_conversion = (60 / timesteps_per_hour) * 60
      # sort keys
      sorted_keys = key_values.sort
      summed_list = ['SUMMED ELECTRICITY:FACILITY', 'SUMMED ELECTRICITY:FACILITY POWER', 'SUMMED ELECTRICITYPRODUCED:FACILITY', 'SUMMED ELECTRICITYPRODUCED:FACILITY POWER', 'SUMMED NET APPARENT POWER', 'SUMMED NET ELECTRIC ENERGY', 'SUMMED NET POWER', 'TRANSFORMER OUTPUT ELECTRIC ENERGY SCHEDULE']
      new_keys = []
      # make sure aggregated timeseries are listed in sorted order before all individual feature timeseries
      sorted_keys.each do |k|
        if summed_list.include? k
          new_keys << k
        end
      end
      sorted_keys.each do |k|
        if !summed_list.include? k
          new_keys << k
        end
      end

      new_keys.each_with_index do |key_value, key_i|

        new_name = ''

        runner.registerInfo("!! TIMESERIES NAME: #{timeseries_name} AND key_value: #{key_value}")

        if key_values.size == 1
          # use timeseries name when only 1 keyvalue
          new_name = timeseries_name
        else
          # use key_value name
          # special case for Zone Thermal Comfort: use both timeseries_name and key_value
          if timeseries_name.include? 'Zone Thermal Comfort'
            new_name = timeseries_name + ' ' + key_value
          else
            new_name = key_value
          end
        end
        new_timeseries << new_name

        ts = sql_file.timeSeries("RUN PERIOD 1", "Zone Timestep", timeseries_name, key_value)
        #runner.registerWarning("attempting to get ts for timeseries_name: #{timeseries_name}, key_value: #{key_value}, ts: #{ts}")
        if n.nil? 
          # first timeseries should always be set
          runner.registerInfo("First timeseries")
          values[i] = ts.get.values
          
          n = values[key_cnt].size 
        elsif ts.is_initialized
          runner.registerInfo('Is Initialized')
          values[key_cnt] = ts.get.values
        else
          runner.registerInfo('Is NOT Initialized')
          values[key_cnt] = Array.new(n, 0)
        end

        # keep certain timeseries to calculate power
        if tsToKeep.include? timeseries_name
          tsToKeepIndexes[timeseries_name] = key_cnt
        end

        # special processing: power
        if powerTimeseries.include? timeseries_name
          #runner.registerInfo("found timeseries: #{timeseries_name}")
          # special case, net series (subtract generation from load)
          if timeseries_name.include? 'Net'
            #runner.registerInfo("Net timeseries found!")
            newVals = Array.new(n,0)
            # Apparent power calc -- only for non-transformers
            
            if timeseries_name.include?('Apparent') 
              if !isTransformerFlag
                #runner.registerInfo("Apparent and !isTransformer")
                (0..n-1).each do |j|
                  newVals[j] = (values[tsToKeepIndexes["Electricity:Facility"]][j].to_f - values[tsToKeepIndexes["ElectricityProduced:Facility"]][j].to_f) / power_conversion / powerFactor
                  j += 1
                end
              end
            elsif timeseries_name.include? 'Net Electric Energy'
               (0..n-1).each do |j|
                newVals[j] = (values[tsToKeepIndexes["Electricity:Facility"]][j].to_f - values[tsToKeepIndexes["ElectricityProduced:Facility"]][j].to_f)
                j += 1
              end
            else
              runner.registerInfo("Power calc")
              # Power calc
              (0..n-1).each do |j|
                newVals[j] = (values[tsToKeepIndexes["Electricity:Facility"]][j].to_f - values[tsToKeepIndexes["ElectricityProduced:Facility"]][j].to_f) / power_conversion
                j += 1
              end
            end

            values[key_cnt] = newVals
          else
            tsToKeepIndexes.each do |key, indexValue|
              if timeseries_name.include? key
                runner.registerInfo("timeseries_name: #{timeseries_name}, key: #{key}")
                # use this timeseries
                newVals = Array.new(n,0)
                # Apparent power calc
                if timeseries_name.include?('Apparent')
                  if !isTransformerFlag
                    (0..n-1).each do |j|
                      newVals[j] = values[indexValue][j].to_f / power_conversion / powerFactor
                      j += 1
                    end
                  end
                else
                  # Power calc
                  (0..n-1).each do |j|
                    newVals[j] = values[indexValue][j].to_f / power_conversion
                    j += 1
                  end
                end
                values[key_cnt] = newVals
              end
            end
          end
        end

        if comfortTimeseries.include? timeseries_name
          # these usually have multiple timeseries (per zone), aggregate into a single series with consistent name and use worst value at each timestep
          
          # set up array if 1st key_value
          if (key_i == 0)
            runner.registerInfo("SETTING UP NEW ARRAY FOR: #{timeseries_name}")
            tmpArray = Array.new(n, 0)
          end

          # add to array (keep max value at each timestep)
          (0..(n-1)).each do |ind|
            # process negative and positive values differently
            tVal = values[key_cnt][ind].to_f
            if tVal < 0
              tmpArray[ind] = [tVal, tmpArray[ind]].min
            else
              tmpArray[ind] = [tVal, tmpArray[ind]].max
            end
          end

          # aggregate and save when all keyvalues have been processed
          if (key_i == new_keys.size - 1)

            hrsOutOfBounds = 0
            if timeseries_name === 'Zone Thermal Comfort Fanger Model PMV'
              (0..(n-1)).each do |ind|
                # -0.5 < x < 0.5 is within bounds
                if values[key_cnt][ind].to_f > 0.5 || values[key_cnt][ind].to_f < -0.5
                  hrsOutOfBounds += 1
                end
              end
              hrsOutOfBounds = hrsOutOfBounds.to_f / timesteps_per_hour
            elsif timeseries_name === 'Zone Thermal Comfort Fanger Model PPD'
              (0..(n-1)).each do |ind|
                # > 20 is outside bounds
                if values[key_cnt][ind].to_f > 20
                  hrsOutOfBounds += 1
                end
              end
              hrsOutOfBounds = hrsOutOfBounds.to_f / timesteps_per_hour
            else
              # this one is already scaled by timestep, no need to divide total
              (0..(n-1)).each do |ind|
                hrsOutOfBounds += values[key_cnt][ind].to_f if values[key_cnt][ind].to_f > 0
              end
            end

            # save variable
            runner.registerInfo("timeseries #{timeseries_name}: hours out of nounds: #{hrsOutOfBounds}")
            add_result(results, timeseries_name.gsub(' ', '_') + '_hours_out_of_bounds', hrsOutOfBounds, "hrs")
          end
        end

        # transformer timeseries
        if isTransformerFlag
          
          # calculate # instances above rating
          # the features & power factors were calculated in VA, then aggregated to get this series (VA)
          if timeseries_name == 'Schedule Value' && key_value == 'SUMMED NET APPARENT POWER'
            numberTimesAboveRating = 0
            numberTimesExtremeRating = 0
            max = 0
            (0..(n-1)).each do |ind|
              if values[key_cnt][ind].to_f > name_plate_rating
                numberTimesAboveRating += 1 
              end
              if values[key_cnt][ind].to_f > (name_plate_rating * 1.20)
                numberTimesExtremeRating += 1
              end
              if values[key_cnt][ind].to_f > max
                max = values[key_cnt][ind]
              end
            end
            runner.registerInfo("name plate rating: #{name_plate_rating}")
            runner.registerInfo("max VA found: #{max}")
            runner.registerInfo("Number of times above transformer rating: #{numberTimesAboveRating}")
            hoursAboveRating = numberTimesAboveRating.to_f / timesteps_per_hour
            hoursExtremeAboveRating = numberTimesExtremeRating.to_f / timesteps_per_hour
            runner.registerInfo("Hours above rating: #{hoursAboveRating}")
            add_result(results, "transformer_hours_above_rating", hoursAboveRating, "hrs")
            add_result(results, "transformer_hours_extreme_above_rating", hoursExtremeAboveRating, "hrs")
          # calculate max and worst days
          elsif timeseries_name == 'Transformer Output Electric Power'

            tsget = ts.get
            datetimes = tsget.dateTimes

            transformer_max_peak = {index: -1, value: -1, timestamp: datetimes[0]}
            transformer_worst_case_RPF = {index: -1, value: 100000000000000, timestamp: datetimes[0]}
            (0..(n-1)).each do |ind|
              if values[key_cnt][ind] > transformer_max_peak[:value]
                transformer_max_peak[:value] = values[key_cnt][ind].to_f
                transformer_max_peak[:index] = ind
                transformer_max_peak[:timestamp] = datetimes[ind]
              end
              if values[key_cnt][ind].to_f < transformer_worst_case_RPF[:value]
                transformer_worst_case_RPF[:value] = values[key_cnt][ind].to_f
                transformer_worst_case_RPF[:index] = ind
                transformer_worst_case_RPF[:timestamp] = datetimes[ind]
              end
            end

            # get start/end of max and worst days
            indexes_per_day = 24 * timesteps_per_hour  
            if (transformer_max_peak[:index] == -1) 
              runner.registerWarning('No Max Peak found for this transformer!')
            else 
              mult = (transformer_max_peak[:index].to_f / indexes_per_day.to_f).floor
              runner.registerInfo("MULTIPLIER: #{mult}")
              max_start = (mult * indexes_per_day).to_i 
              max_end = ((mult + 1) * indexes_per_day).to_i - 1
              runner.registerInfo("max_start: #{max_start}, max_end: #{max_end}, timestamp start: #{datetimes[max_start]}, timestamp end: #{datetimes[max_end]}")
              max_range = []
              (max_start..max_end).each do |j|
                max_range << values[key_cnt][j]
              end
              runner.registerInfo("MAX RANGE: #{max_range}")
           
              # add TRANSFORMER results (max index, index of start/end of max day, hours above rating)
              add_result(results, "transformer_max_peak", transformer_max_peak[:value], "W")  
              add_result(results, "transformer_max_peak_index", transformer_max_peak[:index], "")
              add_result(results, "transformer_max_peak_timestamp", to_displayTime(transformer_max_peak[:timestamp]), "")
              add_result(results, "transformer_max_peak_start_day_index", max_start, "")
              add_result(results, "transformer_max_peak_start_day_timestamp", to_displayTime(datetimes[max_start]), "")
              add_result(results, "transformer_max_peak_end_day_index", max_end, "")
              add_result(results, "transformer_max_peak_end_day_timestamp", to_displayTime(datetimes[max_end]), "")
              add_result(results, "transformer_max_peak_range", max_range.join(','), "")
            end
            
            if (transformer_worst_case_RPF[:index] == -1)
              runner.registerWarning('No Worst Case RPF found to this transformer!')
            else
              mult = (transformer_worst_case_RPF[:index].to_f / indexes_per_day.to_f).floor
              worst_start = (mult * indexes_per_day).to_i
              worst_end = ((mult + 1) * indexes_per_day).to_i - 1
              runner.registerInfo("worst index: #{transformer_worst_case_RPF[:index]}, worst_start: #{worst_start}, worst_end: #{worst_end}, timestamp start: #{datetimes[worst_start]}, timestamp end: #{datetimes[worst_end]}")
              worst_range = []
              (worst_start..worst_end).each do |j|
                worst_range << values[key_cnt][j]
              end
            
              add_result(results, "transformer_worst_case_RPF", transformer_worst_case_RPF[:value], "W")
              add_result(results, "transformer_worst_case_RPF_index", transformer_worst_case_RPF[:index], "")
              add_result(results, "transformer_worst_case_RPF_timestamp", to_displayTime(transformer_worst_case_RPF[:timestamp]), "")
              add_result(results, "transformer_worst_case_RPF_start_day_index", worst_start, "")
              add_result(results, "transformer_worst_case_RPF_start_day_timestamp", to_displayTime(datetimes[worst_start]), "")
              add_result(results, "transformer_worst_case_RPF_end_day_index", worst_end, "")
              add_result(results, "transformer_worst_case_RPF_end_day_timestamp", to_displayTime(datetimes[worst_end]), "")
              add_result(results, "transformer_worst_case_RPF_range", worst_range.join(','), "")
            end
          end
        end
        #increment key_cnt in new_keys loop
        key_cnt += 1
      end
    end

    runner.registerInfo("new timeseries size: #{new_timeseries.size}")
    runner.registerInfo("size of value array: #{values.length}")

    File.open("report.csv", 'w') do |file|
      file.puts(new_timeseries.join(','))
      #file.puts(timeseries.join(','))
      (0...n).each do |i|
        line = []
        values.each_index do |j|
          line << values[j][i]          
          # add_result(results, j, OpenStudio::TimeSeries::sum(values[j]), "")
        end
        file.puts(line.join(',')) 
      end
    end
    
    values = CSV.read("report.csv").transpose
    values.each_with_index do |value, i|
      values[i] = [value[0]] + value[1..-1].collect { |i| i.to_f }
    end
    
    month_map = {0=>"jan", 1=>"feb", 2=>"mar", 3=>"apr", 4=>"may", 5=>"jun", 6=>"jul", 7=>"aug", 8=>"sep", 9=>"oct", 10=>"nov", 11=>"dec"}
    tempIndex = 0
    values.each do |value|
      runner.registerValue(value[0], value[1..-1].inject(0){|sum, x| sum + x})
      add_result(results, value[0], value[1..-1].inject(0){|sum, x| sum + x}, "")
      
      all_values = value[1..-1]
      
      i = 1
      day_sum = 0
      daily_sums = []
      all_values.each do |v|
        day_sum += v
        if i == 24*timesteps_per_hour
          daily_sums << day_sum
          i = 1
          day_sum = 0
        else
          i += 1
        end
      end
      
      monthly_sums = []
      if begin_month == 1 && begin_day_of_month == 1 && end_month == 12 && end_day_of_month == 31
        # horrendous monthly sums
        
        days_per_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        k = 0
        monthly_sum = 0
        days_per_month.each_with_index do |days, d|
          (1..days).each do |day|
            monthly_sum += daily_sums[k]
            k += 1
          end
          
          monthly_sums << monthly_sum
          
          runner.registerValue("#{value[0]}_#{month_map[d]}", monthly_sum)
          add_result(results, "#{value[0]}_#{month_map[d]}", monthly_sum, "")          
          
          monthly_sum = 0
          
        end
        
      end      
      
    end
    
    #closing the sql file
    sql_file.close  
    if datapoint_id == '0' || project_id == '0'
      File.open('report.json', 'w') do |file|
        file << JSON::pretty_generate(results)
      end
    else
      params = {}
      params['project_id'] = project_id
      params['datapoint'] = {'id' => datapoint_id, 'results' => results}
      
      http = Net::HTTP.new(@city_db_url, @port)
      http.read_timeout = 1000
      if @city_db_is_https
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      
      request = Net::HTTP::Post.new("/api/datapoint.json")
      request.add_field('Content-Type', 'application/json')
      request.add_field('Accept', 'application/json')
      request.body = JSON.generate(params)
      # DLM: todo, get these from environment variables or as measure inputs?
      request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])
    
      response = http.request(request)
      if response.code != '200' && response.code != '201' # success
        runner.registerError("Bad response #{response.code}")
        runner.registerError(response.body)
        return false
      end
    end

    #reporting final condition
    runner.registerFinalCondition("Datapoint Report generated successfully.")

    true

  end #end the run method

end #end the measure

# register the measure to be used by the application
DatapointReports.new.registerWithApplication
