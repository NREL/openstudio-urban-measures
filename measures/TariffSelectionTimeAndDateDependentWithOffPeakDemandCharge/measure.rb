# See the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# Import libraries
require "#{File.dirname(__FILE__)}/resources/os_lib_helper_methods"

# Start the measure
class TariffSelectionTimeAndDateDependentWithOffPeakDemandCharge < OpenStudio::Ruleset::WorkspaceUserScript

  # OpenStudio Measure Display Name
  def name
    return "TariffSelectionTimeAndDateDependentWithOffPeakDemandCharge"
  end

  # OpenStudio Measure Display Description
  def description
    return "This measure sets flat rates for gas, water, district heating, and district cooling but has peak, part-peak, and off-peak summer rates and part-peak, and off-peak winter rates for electricity.  The measure also exposes inputs for peak and part-peak hours start and stop times and summer period start and stop dates.  Seasonal maximum demand charges are not included."
  end

  # OpenStudio Measure Display Modeler Description
  def modeler_description
    return "Will add the necessary UtilityCost objects and associated seasonal and time of use schedules into the model.  Maximum demand charges are not included."
  end

  # Define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make choice argument for new Timestep - OS default is 6 or every 10 minutes; this will change the timestep to 4, 2, or 1
	# Options are linked to UtilityCost:Tariff Demand Window Length
    choices = OpenStudio::StringVector.new
    choices << "QuarterHour"
    choices << "HalfHour"
    choices << "FullHour"
	
	# Adding argument for demand_window_length which is the internal variable of the user's choice timestep input
    demand_window_length = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("demand_window_length", choices,true)
    demand_window_length.setDisplayName("Demand Window Length")
    demand_window_length.setDefaultValue("QuarterHour")
    args << demand_window_length

	# Current defaults are according to PG&E E-20 secondary voltage rates and PG&E rate period post-03/01/15
	# ALTER DEFAULTS IF DESIRED
	
    # Adding argument for summer_start_month
    summer_start_month = OpenStudio::Ruleset::OSArgument.makeIntegerArgument("summer_start_month", true)
    summer_start_month.setDisplayName("Month Summer Begins")
    summer_start_month.setDescription("1-12")
    summer_start_month.setDefaultValue(5)
    args << summer_start_month

    # Adding argument for summer_start_day
    summer_start_day = OpenStudio::Ruleset::OSArgument.makeIntegerArgument("summer_start_day", true)
    summer_start_day.setDisplayName("Day Summer Begins")
    summer_start_day.setDescription("1-31")
    summer_start_day.setDefaultValue(1)
    args << summer_start_day

    # Adding argument for summer_end_month
    summer_end_month = OpenStudio::Ruleset::OSArgument.makeIntegerArgument("summer_end_month", true)
    summer_end_month.setDisplayName("Month Summer Ends")
    summer_end_month.setDescription("1-12")
    summer_end_month.setDefaultValue(10)
    args << summer_end_month

    # Adding argument for summer_end_day
    summer_end_day = OpenStudio::Ruleset::OSArgument.makeIntegerArgument("summer_end_day", true)
    summer_end_day.setDisplayName("Day Summer Ends")
    summer_end_day.setDescription("1-31")
    summer_end_day.setDefaultValue(31)
    args << summer_end_day

	# Adding argument for partpeak_start_hour
    partpeak_start_hour = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("partpeak_start_hour", true)
    partpeak_start_hour.setDisplayName("Hour Part-Peak Begins: All Year")
    partpeak_start_hour.setDescription("1-24")
    partpeak_start_hour.setDefaultValue(8.5)
    args << partpeak_start_hour
	
    # Adding argument for peak_start_hour
    peak_start_hour = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("peak_start_hour", true)
    peak_start_hour.setDisplayName("Hour Peak Begins: Summer")
    peak_start_hour.setDescription("1-24")
    peak_start_hour.setDefaultValue(12)
    args << peak_start_hour

    # Adding argument for peak_end_hour
    peak_end_hour = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("peak_end_hour", true)
    peak_end_hour.setDisplayName("Hour Peak Ends: Summer")
    peak_end_hour.setDescription("1-24")
    peak_end_hour.setDefaultValue(18)
    args << peak_end_hour

	# Adding argument for partpeak_end_hour
    partpeak_end_hour = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("partpeak_end_hour", true)
    partpeak_end_hour.setDisplayName("Hour Part-Peak Ends: All Year")
    partpeak_end_hour.setDescription("1-24")
    partpeak_end_hour.setDefaultValue(21.5)
    args << partpeak_end_hour
	
    # Adding argument for elec_rate_sum_peak
    elec_rate_sum_peak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_rate_sum_peak", true)
    elec_rate_sum_peak.setDisplayName("Electric Rate Summer Peak")
    elec_rate_sum_peak.setUnits("$/kWh")
    elec_rate_sum_peak.setDefaultValue(0.17891)
    args << elec_rate_sum_peak

    # Adding argument for elec_rate_sum_partpeak
    elec_rate_sum_partpeak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_rate_sum_partpeak", true)
    elec_rate_sum_partpeak.setDisplayName("Electric Rate Summer Part-Peak")
    elec_rate_sum_partpeak.setUnits("$/kWh")
    elec_rate_sum_partpeak.setDefaultValue(0.17087)
    args << elec_rate_sum_partpeak
	
	# Adding argument for elec_rate_sum_offpeak
    elec_rate_sum_offpeak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_rate_sum_offpeak", true)
    elec_rate_sum_offpeak.setDisplayName("Electric Rate Summer Off-Peak")
    elec_rate_sum_offpeak.setUnits("$/kWh")
    elec_rate_sum_offpeak.setDefaultValue(0.14642)
    args << elec_rate_sum_offpeak

    # Adding argument for elec_rate_win_partpeak
    elec_rate_win_partpeak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_rate_win_partpeak", true)
    elec_rate_win_partpeak.setDisplayName("Electric Rate Winter Part-Peak")
    elec_rate_win_partpeak.setUnits("$/kWh")
    elec_rate_win_partpeak.setDefaultValue(0.12750)
    args << elec_rate_win_partpeak

    # Adding argument for elec_rate_win_offpeak
    elec_rate_win_offpeak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_rate_win_offpeak", true)
    elec_rate_win_offpeak.setDisplayName("Electric Rate Winter Off-Peak")
    elec_rate_win_offpeak.setUnits("$/kWh")
    elec_rate_win_offpeak.setDefaultValue(0.10654)
    args << elec_rate_win_offpeak

    # Adding argument for elec_demand_sum_peak
    elec_demand_sum_peak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_demand_sum_peak", true)
    elec_demand_sum_peak.setDisplayName("Electric Demand Charge Summer Peak")
    elec_demand_sum_peak.setUnits("$/kW")
    elec_demand_sum_peak.setDefaultValue(16.23)
    args << elec_demand_sum_peak

    # Adding argument for elec_demand_sum_partpeak
    elec_demand_sum_partpeak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_demand_sum_partpeak", true)
    elec_demand_sum_partpeak.setDisplayName("Electric Demand Charge Summer Part-Peak")
    elec_demand_sum_partpeak.setUnits("$/kW")
    elec_demand_sum_partpeak.setDefaultValue(16.23)
    args << elec_demand_sum_partpeak

    # Adding argument for elec_demand_sum_offpeak
    elec_demand_sum_offpeak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_demand_sum_offpeak", true)
    elec_demand_sum_offpeak.setDisplayName("Electric Demand Charge Summer Off-Peak")
    elec_demand_sum_offpeak.setUnits("$/kW")
    elec_demand_sum_offpeak.setDefaultValue(16.23)
    args << elec_demand_sum_offpeak

    # Adding argument for elec_demand_win_partpeak
    elec_demand_win_partpeak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_demand_win_partpeak", true)
    elec_demand_win_partpeak.setDisplayName("Electric Demand Charge Winter Part-Peak")
    elec_demand_win_partpeak.setUnits("$/kW")
    elec_demand_win_partpeak.setDefaultValue(8.00)
    args << elec_demand_win_partpeak

	# Adding argument for elec_demand_win_offpeak
    elec_demand_win_offpeak = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("elec_demand_win_offpeak", true)
    elec_demand_win_offpeak.setDisplayName("Electric Demand Charge Winter Off-Peak")
    elec_demand_win_offpeak.setUnits("$/kW")
    elec_demand_win_offpeak.setDefaultValue(8.00)
    args << elec_demand_win_offpeak

    # Adding argument for gas_rate
    gas_rate = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("gas_rate", true)
    gas_rate.setDisplayName("Gas Rate")
    gas_rate.setUnits("$/therm")
    gas_rate.setDefaultValue(0.85)
    args << gas_rate

    # Adding argument for water_rate
    water_rate = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("water_rate", true)
    water_rate.setDisplayName("Water Rate")
    water_rate.setUnits("$/gal")
    water_rate.setDefaultValue(0.005)
    args << water_rate

    # Adding argument for disthtg_rate
    disthtg_rate = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("disthtg_rate", true)
    disthtg_rate.setDisplayName("District Heating Rate")
    disthtg_rate.setUnits("$/kBtu")
    disthtg_rate.setDefaultValue(0.2)
    args << disthtg_rate

    # Adding argument for distclg_rate
    distclg_rate = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("distclg_rate", true)
    distclg_rate.setDisplayName("District Cooling Rate")
    distclg_rate.setUnits("$/kBtu")
    distclg_rate.setDefaultValue(0.2)
    args << distclg_rate

    return args
  end 

  # Define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # Assign the user inputs "args" to variables
	# Return false if any errors
    args  = OsLib_HelperMethods.createRunVariables(runner, workspace,user_arguments, arguments(workspace))
    if !args then return false end

    # Check expected values of double arguments
	# Variables should be set to true if checks out
    zero_24 = OsLib_HelperMethods.checkDoubleAndIntegerArguments(runner, user_arguments,{"min"=>0.0,"max"=>24.0,"min_eq_bool"=>true,"max_eq_bool"=>true,"arg_array" =>["peak_start_hour","peak_end_hour"]})
    one_31 = OsLib_HelperMethods.checkDoubleAndIntegerArguments(runner, user_arguments,{"min"=>1.0,"max"=>31.0,"min_eq_bool"=>true,"max_eq_bool"=>true,"arg_array" =>["summer_start_day","summer_end_day"]})
    one_12 = OsLib_HelperMethods.checkDoubleAndIntegerArguments(runner, user_arguments,{"min"=>1.0,"max"=>12.0,"min_eq_bool"=>true,"max_eq_bool"=>true,"arg_array" =>["summer_start_month","summer_end_month"]})

    # Return false if variables do not check out
    if !zero_24 then return false end
    if !one_31 then return false end
    if !one_12 then return false end	

    # Reporting how many tariffs already exist in the model
    starting_tariffs = workspace.getObjectsByType("UtilityCost:Tariff".to_IddObjectType)
    runner.registerInitialCondition("The model started with #{starting_tariffs.size} tariff objects.")

    # Map demand_window_length to integer "demand_window_per_hour" which is initialized to nil
    demand_window_per_hour = nil
    if args['demand_window_length'] == "QuarterHour"
      demand_window_per_hour = 4
    elsif args['demand_window_length'] == "HalfHour"
      demand_window_per_hour = 2
    elsif args['demand_window_length'] == "FullHour"
      demand_window_per_hour = 1
    else
      # Shouldn't get here from current choice list options
    end

    # Make sure demand window length is divisible by timestep even though the internal integer options 1,2,4,6 should all work
	# If there is already a Timestep object of which there should be one set to 6...
    if not workspace.getObjectsByType("Timestep".to_IddObjectType).empty?
      initial_timestep = workspace.getObjectsByType("Timestep".to_IddObjectType)[0].getString(0).get

	  # If 6.0/4.0 = 6.0/4.0.truncate or if 1.5 = 1...this would fail because the two variables are not the same - this would never succeed given the choice arguments of 4, 2, and 1
      if initial_timestep.to_f / demand_window_per_hour.to_f == (initial_timestep.to_f / demand_window_per_hour.to_f).truncate
        runner.registerInfo("The demand window length of every #{args['demand_window_length']} is compatible with the current setting of #{initial_timestep} timesteps per hour.")
	  # Else set the new timestep according to demand_window_per_hour
      else
        workspace.getObjectsByType("Timestep".to_IddObjectType)[0].setString(0,demand_window_per_hour.to_s)
        runner.registerInfo("Updating the timesteps per hour in the model from #{initial_timestep} to #{demand_window_per_hour.to_s} to be compatible with the demand window length of every #{args['demand_window_length']}")
      end
	# If there is not already a Timestep object for some reason, add a new Timestep object to the workspace   
    else
      new_object_string = "
      Timestep,
        #{demand_window_per_hour.to_s};         !- Number of Timesteps per Hour
        "
      idfObject = OpenStudio::IdfObject::load(new_object_string)
      object = idfObject.get
      wsObject = workspace.addObject(object)
      new_object = wsObject.get
      runner.registerInfo("No timestep object found. Added a new timestep object set to #{demand_window_per_hour.to_s} timesteps per hour")
    end
	
    # Get variables for time of day and year
    ms = args['summer_start_month']
    ds = args['summer_start_day']
    mf = args['summer_end_month']
    df = args['summer_end_day']
    ps = args['peak_start_hour']
    pf = args['peak_end_hour']
	pps = args['partpeak_start_hour']
	ppf = args['partpeak_end_hour']
	# For example, psh and pfh take only the hour, 9, if the user were to input 9.533
    psh = ps.truncate
    pfh = pf.truncate
    # For example, psm and pfm would take the remainder, 0.503, then *60 to get 31.98, and then truncate it to 31
	psm = ((ps-ps.truncate)*60).truncate
    pfm = ((pf-pf.truncate)*60).truncate
	# Same thing but for part-peak hours
	ppsh = pps.truncate
    ppfh = ppf.truncate
	ppsm = ((pps-pps.truncate)*60).truncate
    ppfm = ((ppf-ppf.truncate)*60).truncate
	
	# Makes sure that peak hours are contained within part-peak hours entirely.  They may share the same start and end times, but peak hours may not start before part-peak hours start and may not end after part-peak hours end
	if ppsh + ppsm/60.0 > psh + psm/60.0 
		runner.registerInfo("Peak Hours start before Part-Peak Hours start. Consider setting Part-Peak Hours start time to equal Peak Hours start time.")
		return false 
	elsif ppfh + ppfm/60.0 < pfh + pfm/60.0 
		runner.registerInfo("Peak Hours end after Part-Peak Hours end. Consider setting Part-Peak Hours end time to equal Peak Hours end time.")
		return false 
	end
		
	# If the user didn't override the default values to all equal 0...shouldn't happen
    if args['elec_rate_sum_peak'].abs + args['elec_rate_sum_partpeak'].abs + args['elec_rate_sum_offpeak'].abs + args['elec_rate_win_partpeak'].abs + args['elec_rate_win_offpeak'].abs + args['elec_demand_sum_peak'].abs + args['elec_demand_sum_partpeak'].abs + args['elec_demand_sum_offpeak'].abs + args['elec_demand_win_partpeak'].abs + args['elec_demand_win_offpeak'].abs > 0

      # Make type limits schedule object that allows 1,2,3,4
      new_object_string = "
      ScheduleTypeLimits,
        Tariff Analogs,                         !- Name
        0,                                      !- Lower Limit Value {BasedOnField A3}
        5,                                      !- Upper Limit Value {BasedOnField A3}
        DISCRETE;                               !- Numeric Type
        "
      type_limits = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
	  
	  # According to EnergyPlus, Season Schedules called by Tariff objects will link the values...
	  #   1 to Winter
	  #   2 to Spring
	  #   3 to Summer
	  #   4 to Autumn

      # Make two season schedule which calls the type limits schedule "number"
	  # From 1/1 to ms/ds is winter, ms/ds to mf/df is summer, mf/df to 12/31 is winter
      new_object_string = "
      Schedule:Compact,
        TwoSeasonSchedule,                      !- Name
        Tariff Analogs,                         !- Schedule Type Limits Name
        Through: #{ms}/#{ds}, For: AllDays, Until: 24:00, 1,
        Through: #{mf}/#{df}, For: AllDays, Until: 24:00, 3,
        Through: 12/31,       For: AllDays, Until: 24:00, 1;
        "
      two_season_schedule = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

	  # According to EnergyPlus, Time of Use Schedules called by Tariff objects will link the values...
	  #   1 to Peak
	  #   2 to Shoulder
	  #   3 to OffPeak
	  #   4 to MidPeak
	  
      # Make time of day schedule which includes peak hours and part peak hours for summer and just part peak hours for winter
	  # If part-peak hours start at the same time peak hours start
      if ppsh + ppsm/60.0 == psh + psm/60.0
	    # For summer, from 00:00 to ppsh:ppsm is OffPeak, ppsh:ppsm to pfh:pfm is Peak, pfh:pfm to ppfh:ppfm is MidPeak, ppfh:ppfm to 24:00 is OffPeak; Weekends are always OffPeak
		# For winter, from 00:00 to ppsh:ppsm is OffPeak, ppsh:ppsm to ppfh:ppfm is MidPeak, ppfh:ppfm to 24:00 is OffPeak; Weekends are always OffPeak
		new_object_string = "
        Schedule:Compact,
          TimeOfDaySchedule,                      !- Name
          Tariff Analogs,                         !- Schedule Type Limits Name
          Through: #{ms}/#{ds}, For: Weekdays,     Until: #{ppsh}:#{ppsm}, 3,
		  						         	       Until: #{ppfh}:#{ppfm}, 4,
										           Until: 24:00,           3,
						        For: AllOtherDays, Until: 24:00,           3;
		  Through: #{mf}/#{df}, For: Weekdays,     Until: #{ppsh}:#{ppsm}, 3,
		                                           Until: #{pfh}:#{pfm},   1,
								         	       Until: #{ppfh}:#{ppfm}, 4,
										           Until: 24:00,           3,
						        For: AllOtherDays, Until: 24:00,           3;
		  Through: 12/31,       For: Weekdays,     Until: #{ppsh}:#{ppsm}, 3,
								         	       Until: #{ppfh}:#{ppfm}, 4,
										           Until: 24:00,           3,
						        For: AllOtherDays, Until: 24:00,           3;
        "
	  # Else if part-peak hours end at the same time peak hours end
	  elsif ppfh + ppfm/60.0 == pfh + pfm/60.0
		# For summer, from 00:00 to ppsh:ppsm is OffPeak, ppsh:ppsm to psh:psm is MidPeak, psh:psm to ppfh:ppfm is Peak, ppfh:ppfm to 24:00 is OffPeak; Weekends are always OffPeak
		# For winter, from 00:00 to ppsh:ppsm is OffPeak, ppsh:ppsm to ppfh:ppfm is MidPeak, ppfh:ppfm to 24:00 is OffPeak; Weekends are always OffPeak
        new_object_string = "
        Schedule:Compact,
          TimeOfDaySchedule,                      !- Name
          Tariff Analogs,                         !- Schedule Type Limits Name
          Through: #{ms}/#{ds}, For: Weekdays,     Until: #{ppsh}:#{ppsm}, 3,
		         				         	       Until: #{ppfh}:#{ppfm}, 4,
										           Until: 24:00,           3,
						        For: AllOtherDays, Until: 24:00,           3;
		  Through: #{mf}/#{df}, For: Weekdays,     Until: #{ppsh}:#{ppsm}, 3,
		                                           Until: #{psh}:#{psm},   4,			
		  						         	       Until: #{ppfh}:#{ppfm}, 1,
										           Until: 24:00,           3,
						        For: AllOtherDays, Until: 24:00,           3;
		  Through: 12/31,       For: Weekdays,     Until: #{ppsh}:#{ppsm}, 3,
								         	       Until: #{ppfh}:#{ppfm}, 4,
										           Until: 24:00,           3,
						        For: AllOtherDays, Until: 24:00,           3;
        "
	  else
	    # For summer, from 00:00 to ppsh:ppsm is OffPeak, ppsh:ppsm to psh:psm is MidPeak, psh:psm to pfh:pfm is Peak, pfh:pfm to ppfh:ppfm is MidPeak, ppfh:ppfm to 24:00 is OffPeak; Weekends are always OffPeak
		# For winter, from 00:00 to ppsh:ppsm is OffPeak, ppsh:ppsm to ppfh:ppfm is MidPeak, ppfh:ppfm to 24:00 is OffPeak; Weekends are always OffPeak
		new_object_string = "
        Schedule:Compact,
          TimeOfDaySchedule,                      !- Name
          Tariff Analogs,                         !- Schedule Type Limits Name
          Through: #{ms}/#{ds}, For: Weekdays,     Until: #{ppsh}:#{ppsm}, 3,
		         				         	       Until: #{ppfh}:#{ppfm}, 4,
										           Until: 24:00,           3,
						        For: AllOtherDays, Until: 24:00,           3;
		  Through: #{mf}/#{df}, For: Weekdays,     Until: #{ppsh}:#{ppsm}, 3,
		                                           Until: #{psh}:#{psm},   4,			
		  						         	       Until: #{pfh}:#{pfm},   1,
		  						         	       Until: #{ppfh}:#{ppfm}, 4,
										           Until: 24:00,           3,
			                    For: AllOtherDays, Until: 24:00,           3;
		  Through: 12/31,       For: Weekdays,     Until: #{ppsh}:#{ppsm}, 3,
		         				         	       Until: #{ppfh}:#{ppfm}, 4,
										           Until: 24:00,           3,
						        For: AllOtherDays, Until: 24:00,           3;
		"
      end
      time_of_day_schedule = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
	  
      # Make an electric tariff object
      new_object_string = "
      UtilityCost:Tariff,
        ElectricityTariff,                      !- Name
        ElectricityPurchased:Facility,          !- Output Meter Name
        kWh,                                    !- Conversion Factor Choice
        ,                                       !- Energy Conversion Factor
        ,                                       !- Demand Conversion Factor
        #{time_of_day_schedule.getString(0)},   !- Time of Use Period Schedule Name
        #{two_season_schedule.getString(0)},    !- Season Schedule Name
        ,                                       !- Month Schedule Name
        #{args['demand_window_length']},        !- Demand Window Length
        0.0;                                    !- Monthly Charge or Variable Name
        "
      electric_tariff = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

      # Make UtilityCost:Charge:Simple objects for ELECTRICITY RATES
	  # Summer OnPeak Charge
	  new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffSummerPeakEnergyCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        peakEnergy,                             !- Source Variable
        Summer,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{args['elec_rate_sum_peak']};          !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_sum_peak = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
	  
	  # Summer PartPeak Charge
      new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffSummerPartPeakEnergyCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        midPeakEnergy,                          !- Source Variable
        Summer,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{args['elec_rate_sum_partpeak']};      !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_sum_partpeak = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

	  # Summer OffPeak Charge	  
      new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffSummerOffPeakEnergyCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        offPeakEnergy,                          !- Source Variable
        Summer,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{args['elec_rate_sum_offpeak']};       !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_sum_offpeak = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

	  # Winter PartPeak Charge
      new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffWinterPartPeakEnergyCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        midPeakEnergy,                          !- Source Variable
        Winter,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{args['elec_rate_win_partpeak']};      !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_win_partpeak = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

	  # Winter OffPeak Charge	
      new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffWinterOffPeakEnergyCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        offPeakEnergy,                          !- Source Variable
        Winter,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{args['elec_rate_win_offpeak']};       !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_win_offpeak = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

	  # Make UtilityCost:Charge:Simple objects for ELECTRICITY DEMAND CHARGES
      # Summer OnPeak Demand Charge
	  new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffSummerPeakWithMaxDemandCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        peakDemand,                             !- Source Variable
        Summer,                                 !- Season
        DemandCharges,                          !- Category Variable Name
        #{args['elec_demand_sum_peak']};        !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_sum_peak_demand = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

	  # Summer PartPeak Demand Charge
	  new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffSummerPartPeakDemandCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        midPeakDemand,                          !- Source Variable
        Summer,                                 !- Season
        DemandCharges,                          !- Category Variable Name
        #{args['elec_demand_sum_partpeak']};    !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_sum_partpeak_demand = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
	  
	  # Summer OffPeak Demand Charge
	  new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffSummerOffPeakDemandCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        offPeakDemand,                          !- Source Variable
        Summer,                                 !- Season
        DemandCharges,                          !- Category Variable Name
        #{args['elec_demand_sum_offpeak']};     !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_sum_offpeak_demand = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
	  
	  # Winter PartPeak Demand Charge + Max Winter Demand Charge
      new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffWinterPartPeakDemandCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        midPeakDemand,                          !- Source Variable
        Winter,                                 !- Season
        DemandCharges,                          !- Category Variable Name
        #{args['elec_demand_win_partpeak']};    !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_win_partpeak_demand = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
	  
	  # Winter OffPeak Demand Charge: if max demand charges are included, there should be no off peak demand charges
      new_object_string = "
      UtilityCost:Charge:Simple,
        ElectricityTariffWinterOffPeakDemandCharge, !- Name
        ElectricityTariff,                      !- Tariff Name
        offPeakDemand,                          !- Source Variable
        Winter,                                 !- Season
        DemandCharges,                          !- Category Variable Name
        #{args['elec_demand_win_offpeak']};     !- Cost per Unit Value or Variable Name
        "
      elec_utility_cost_win_offpeak_demand = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
    end

    # Gas tariff object
    if args['gas_rate'] > 0
      new_object_string = "
      UtilityCost:Tariff,
        Gas Tariff,                             !- Name
        Gas:Facility,                           !- Output Meter Name
        Therm,                                  !- Conversion Factor Choice
        ,                                       !- Energy Conversion Factor
        ,                                       !- Demand Conversion Factor
        ,                                       !- Time of Use Period Schedule Name
        ,                                       !- Season Schedule Name
        ,                                       !- Month Schedule Name
        Day,                                    !- Demand Window Length
        0.0;                                    !- Monthly Charge or Variable Name
        "
      gas_tariff = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

      # Make UtilityCost:Charge:Simple object for gas
      new_object_string = "
      UtilityCost:Charge:Simple,
        GasTariffEnergyCharge, !- Name
        Gas Tariff,                             !- Tariff Name
        totalEnergy,                            !- Source Variable
        Annual,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{args['gas_rate']};                    !- Cost per Unit Value or Variable Name
        "
      gas_utility_cost = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
    end

    # Conversion for water tariff rate from $/gal to $/m^3
    dollars_per_gallon = args['water_rate']
    dollars_per_meter_cubed = OpenStudio.convert(dollars_per_gallon,"1/gal","1/m^3").get

    # Water tariff object
    if args['water_rate'] > 0
      new_object_string = "
      UtilityCost:Tariff,
        Water Tariff,                           !- Name
        Water:Facility,                         !- Output Meter Name
        UserDefined,                            !- Conversion Factor Choice
        1,                                      !- Energy Conversion Factor
        ,                                       !- Demand Conversion Factor
        ,                                       !- Time of Use Period Schedule Name
        ,                                       !- Season Schedule Name
        ,                                       !- Month Schedule Name
        ,                                       !- Demand Window Length
        0.0;                                    !- Monthly Charge or Variable Name
        "
      water_tariff = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

      # Make UtilityCost:Charge:Simple objects for water
      new_object_string = "
      UtilityCost:Charge:Simple,
        WaterTariffEnergyCharge, !- Name
        Water Tariff,                           !- Tariff Name
        totalEnergy,                            !- Source Variable
        Annual,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{dollars_per_meter_cubed};             !- Cost per Unit Value or Variable Name
        "
      water_utility_cost = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
    end

    # District Heating tariff object
    if args['disthtg_rate'] > 0
      new_object_string = "
      UtilityCost:Tariff,
        DistrictHeating Tariff,                 !- Name
        DistrictHeating:Facility,               !- Output Meter Name
        KBtu,                                   !- Conversion Factor Choice
        ,                                       !- Energy Conversion Factor
        ,                                       !- Demand Conversion Factor
        ,                                       !- Time of Use Period Schedule Name
        ,                                       !- Season Schedule Name
        ,                                       !- Month Schedule Name
        Day,                                    !- Demand Window Length
        0.0;                                    !- Monthly Charge or Variable Name
        "
      disthtg_tariff = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

      # Make UtilityCost:Charge:Simple objects for district heating
      # value = OpenStudio::convert(args['gas_rate'],"1/therms","1/Kbtu").get # todo - get conversion working
      value = args['disthtg_rate']/99.98 # $/therm to $/Kbtu
      new_object_string = "
      UtilityCost:Charge:Simple,
        DistrictHeatingTariffEnergyCharge,      !- Name
        DistrictHeating Tariff,                 !- Tariff Name
        totalEnergy,                            !- Source Variable
        Annual,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{value};                               !- Cost per Unit Value or Variable Name
        "
      disthtg_utility_cost = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
    end

    # District Cooling tariff object
    if args['distclg_rate'] > 0
      new_object_string = "
      UtilityCost:Tariff,
        DistrictCooling Tariff,                 !- Name
        DistrictCooling:Facility,               !- Output Meter Name
        KBtu,                                   !- Conversion Factor Choice
        ,                                       !- Energy Conversion Factor
        ,                                       !- Demand Conversion Factor
        ,                                       !- Time of Use Period Schedule Name
        ,                                       !- Season Schedule Name
        ,                                       !- Month Schedule Name
        Day,                                    !- Demand Window Length
        0.0;                                    !- Monthly Charge or Variable Name
        "
      distclg_tariff = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get

      # Make UtilityCost:Charge:Simple objects for district cooling
      # value = OpenStudio::convert(args['gas_rate'],"1/therms","1/Kbtu").get # todo - get conversion working
      value = args['distclg_rate']/99.98 # $/therm to $/Kbtu
      new_object_string = "
      UtilityCost:Charge:Simple,
        DistrictCoolingTariffEnergyCharge,      !- Name
        DistrictCooling Tariff,                 !- Tariff Name
        totalEnergy,                            !- Source Variable
        Annual,                                 !- Season
        EnergyCharges,                          !- Category Variable Name
        #{value};                               !- Cost per Unit Value or Variable Name
      "
      distclg_utility_cost = workspace.addObject(OpenStudio::IdfObject::load(new_object_string).get).get
    end
    
    # Report final condition of model
    finishing_tariffs = workspace.getObjectsByType("UtilityCost:Tariff".to_IddObjectType)
    runner.registerFinalCondition("The model finished with #{finishing_tariffs.size} tariff objects.")

    return true
	
  end

end 

# Register the measure to be used by the application
TariffSelectionTimeAndDateDependentWithOffPeakDemandCharge.new.registerWithApplication
