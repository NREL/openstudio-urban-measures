require 'json'
require 'net/http'

#start the measure
class DatapointReports < OpenStudio::Ruleset::ReportingUserScript

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
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
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

    timeseries = ["Electricity:Facility", "Gas:Facility", "District Cooling Chilled Water Rate", "District Cooling Mass Flow Rate", 
                  "District Cooling Inlet Temperature", "District Cooling Outlet Temperature", "District Heating Hot Water Rate", 
                  "District Heating Mass Flow Rate", "District Heating Inlet Temperature", "District Heating Outlet Temperature"]

    timeseries.each do |ts|
      result << OpenStudio::IdfObject.load("Output:Variable,*,#{ts},timestep;").get
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
        @runner.registerWarning("Value for #{name}' is nil")
      elsif units.nil?
        @runner.registerValue(name, value)
      else
        @runner.registerValue(name, value, units)
      end
    end
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
    
    @port = 80
    if md = /http:\/\/(.*):(\d+)/.match(city_db_url)
      @city_db_url = md[1]
      @port = md[2]
    elsif /http:\/\/([^:\/]*)/.match(city_db_url)
      @city_db_url = md[1]
    end
    
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
      OpenStudio::MonthOfYear.getValues.each do |month|
        if month >= 1 and month <= 12
          fuel_and_month_aggregation = 0.0
          OpenStudio::EndUseCategoryType::getValues.each do |category_type|
            if sql_file.energyConsumptionByMonth(OpenStudio::EndUseFuelType.new(fuel_str), OpenStudio::EndUseCategoryType.new(category_type), OpenStudio::MonthOfYear.new(month)).is_initialized
              val_in_j = sql_file.energyConsumptionByMonth(OpenStudio::EndUseFuelType.new(fuel_str), OpenStudio::EndUseCategoryType.new(category_type), OpenStudio::MonthOfYear.new(month)).get
              fuel_and_month_aggregation += val_in_j
            end
          end
          fuel_and_month_aggregation *= mult_factor
          month_str = OpenStudio::MonthOfYear.new(month).valueDescription
          prefix_str = OpenStudio::toUnderscoreCase("#{month_str}_end_use_#{fuel_str}_eui")
          add_result(results, prefix_str, fuel_and_month_aggregation, runner_units_to, runner_units)
          short_name = "#{month_str[0..2]} #{short_os_fuel(fuel_str)} EUI"
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

    # queries with one-line API methods
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
    
    # get timeseries
    timeseries = ["Electricity:Facility", "Gas:Facility", "DistrictCooling:Facility", "DistrictHeating:Facility", 
                  "District Cooling Chilled Water Rate", "District Cooling Mass Flow Rate", "District Cooling Inlet Temperature", "District Cooling Outlet Temperature", 
                  "District Heating Hot Water Rate", "District Heating Mass Flow Rate", "District Heating Inlet Temperature", "District Heating Outlet Temperature"]
    
    n = nil
    values = []
    timeseries.each_index do |i|
      timeseries_name = timeseries[i]
      key_values = sql_file.availableKeyValues("RUN PERIOD 1", "Zone Timestep", timeseries_name)
      if key_values.empty?
        key_value = ""
      else
        key_value = key_values[0]
      end
      ts = sql_file.timeSeries("RUN PERIOD 1", "Zone Timestep", timeseries_name, key_value)
      if n.nil? 
        # first timeseries should always be set
        values[i] = ts.get.values
        n = values[i].size 
      elsif ts.is_initialized
        values[i] = ts.get.values
      else
        values[i] = Array.new(n, 0)
      end
    end

    File.open("report.csv", 'w') do |file|
      file.puts(timeseries.join(','))
      (0...n).each do |i|
        line = []
        values.each_index do |j|
          line << values[j][i]
        end
        file.puts(line.join(',')) 
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
