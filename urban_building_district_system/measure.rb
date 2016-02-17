# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require "#{File.dirname(__FILE__)}/resources/HVAC"
require "#{File.dirname(__FILE__)}/resources/OsLib_Schedules"

# start the measure
class UrbanBuildingDistrictSystem < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "UrbanBuildingDistrictSystem"
  end

  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # District system type
    district_system_types = OpenStudio::StringVector.new
    district_system_types << "Conventional"
    district_system_types << "Geothermal ambient loop"
    district_system_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("district_system_type", district_system_types, true)
    district_system_type.setDisplayName("Type of district system to model")
    district_system_type.setDefaultValue("Conventional")
    args << district_system_type

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    district_system_type = runner.getStringArgumentValue("district_system_type", user_arguments)
    chiller_type = "AirCooled" # WaterCooled, AirCooled
    zone_hvac = "GSHP" # GSHP, WSHP, FanCoil, ASHP, Baseboard, Radiant, DualDuct
    
    unless district_system_type == "Conventional"
        return false
    end

    # SCHEDULES
    hot_water_setpoint_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "HW-Loop-Temp-Schedule", "default_day" => ["All Days", [24,67.0]]})
    radiant_hot_water_setpoint_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New HW-Radiant-Loop-Temp-Schedule", "default_day" => ["All Days", [24,45.0]]})
    chilled_water_setpoint_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "CW-Loop-Temp-Schedule", "default_day" => ["All Days", [24,6.7]]})                                                                                 
    radiant_chilled_water_setpoint_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New CW-Radiant-Loop-Temp-Schedule", "default_day" => ["All Days", [24,15.0]]})
    primary_sat_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "Cold Deck Temperature Setpoint Schedule", "default_day" => ["All Days",[24,12.8]]})
    
    hp_loop_schedule = nil
    hp_loop_cooling_schedule = nil
    hp_loop_heating_schedule = nil
    if zone_hvac == "GSHP"
        hp_loop_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New HP-Loop-Temp-Schedule", "default_day" => ["All Days",[24,21]]})
        hp_loop_cooling_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New HP-Loop-Clg-Temp-Schedule", "default_day" => ["All Days",[24,21]]})
        hp_loop_heating_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New HP-Loop-Htg-Temp-Schedule", "default_day" => ["All Days",[24,5]]})                                                                               
    elsif zone_hvac == "WSHP"
        hp_loop_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New HP-Loop-Temp-Schedule", "default_day" => ["All Days",[24,30]]}) #PNNL
        hp_loop_cooling_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New HP-Loop-Clg-Temp-Schedule", "default_day" => ["All Days",[24,30]]}) #PNNL
        hp_loop_heating_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New HP-Loop-Htg-Temp-Schedule", "default_day" => ["All Days",[24,20]]}) #PNNL
    end

    mean_radiant_heating_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New Office Mean Radiant Heating Setpoint Schedule", "winter_design_day" => [[24,18.8]], "summer_design_day" => [[6,18.3],[22,18.8],[24,18.3]], "default_day" => ["Weekday",[6,18.3],[22,18.8],[24,18.3]], "rules" => [["Saturday","1/1-12/31","Sat",[6,18.3],[18,18.8],[24,18.3]], ["Sunday","1/1-12/31","Sun",[24,18.3]]]})
    mean_radiant_cooling_schedule = OsLib_Schedules.createComplexSchedule(model, {"name" => "New Office Mean Radiant Cooling Setpoint Schedule", "winter_design_day" => [[6,26.7],[22,24.0],[24,26.7]], "summer_design_day" => [[24,24.0]], "default_day" => ["Weekday",[6,26.7],[22,24.0],[24,26.7]], "rules" => [["Saturday","1/1-12/31","Sat",[6,26.7],[18,24.0],[24,26.7]], ["Sunday","1/1-12/31","Sun",[24,26.7]]]})

    runner.registerInfo("Removing existing HVAC.")
    HelperMethods.remove_existing_hvac_equipment(model, runner)
    
    # PLANT LOOPS
    
    hot_water_plant = nil
    radiant_hot_water_plant = nil
    chilled_water_plant = nil
    radiant_chilled_water_plant = nil
    
    runner.registerInfo("Creating hot water plant.")    
    hot_water_plant = HelperMethods.create_hot_water_plant(model, runner, hot_water_setpoint_schedule)
    
    runner.registerInfo("Creating radiant hot water plant.")
    # radiant_hot_water_plant = HelperMethods.create_radiant_hot_water_plant(model, runner, radiant_hot_water_setpoint_schedule)
    
    runner.registerInfo("Creating chilled water plant.")
    chilled_water_plant = HelperMethods.create_chilled_water_plant(model, runner, chilled_water_setpoint_schedule, chiller_type)     
    
    runner.registerInfo("Creating radiant chilled water plant.")
    # radiant_chilled_water_plant = HelperMethods.create_radiant_chilled_water_plant(model, runner, radiant_chilled_water_setpoint_schedule, chiller_type)    
    
    # CONDENSER LOOPS
    
    runner.registerInfo("Creating condenser loop.")
    condenser_loop, heat_pump_loop = HelperMethods.create_condenser_loop(model, runner, zone_hvac, hp_loop_schedule, hp_loop_cooling_schedule, hp_loop_heating_schedule)
    
    # AIR LOOPS
    
    primary_airloops = HelperMethods.create_primary_air_loop(model, runner, hot_water_plant, chilled_water_plant, primary_sat_schedule)
    
    # EQUIPMENT
    
    HelperMethods.create_primary_zone_equipment(model, runner, hot_water_plant, radiant_hot_water_plant, chilled_water_plant, radiant_chilled_water_plant, heat_pump_loop, mean_radiant_heating_schedule, mean_radiant_cooling_schedule, zone_hvac)
    
    return true

  end
  
end

# register the measure to be used by the application
UrbanBuildingDistrictSystem.new.registerWithApplication
