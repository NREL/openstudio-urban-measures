# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class AddDistrictSystem < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Add district system"
  end

  # human readable description
  def description
    return "Add district system"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Add district system"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # the type of system to add to the building
    systems = OpenStudio::StringVector.new
    systems << "None"
    systems << "Central Hot and Chilled Water"
    systems << "Ambient Loop"
    system_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('system_type', systems, true)
    system_type.setDisplayName("System Type")
    system_type.setDefaultValue("None")
    system_type.setDescription("Type of central system.")
    args << system_type

    return args
  end
  
  def add_system_7_commercial(model)
  
    # Hot Water Plant

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    hw_loop.setName("Hot Water Loop")
    hw_sizing_plant = hw_loop.sizingPlant
    hw_sizing_plant.setLoopType("Heating")
    hw_sizing_plant.setDesignLoopExitTemperature(82.0) #TODO units
    hw_sizing_plant.setLoopDesignTemperatureDifference(11.0)

    hw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    boiler = OpenStudio::Model::BoilerHotWater.new(model)

    boiler_eff_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
    boiler_eff_f_of_temp.setName("Boiler Efficiency")
    boiler_eff_f_of_temp.setCoefficient1Constant(1.0)
    boiler_eff_f_of_temp.setInputUnitTypeforX("Dimensionless")
    boiler_eff_f_of_temp.setInputUnitTypeforY("Dimensionless")
    boiler_eff_f_of_temp.setOutputUnitType("Dimensionless")

    boiler.setNormalizedBoilerEfficiencyCurve(boiler_eff_f_of_temp)
    boiler.setEfficiencyCurveTemperatureEvaluationVariable("LeavingBoiler")

    boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    hw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # Add the components to the hot water loop
    hw_supply_inlet_node = hw_loop.supplyInletNode
    hw_supply_outlet_node = hw_loop.supplyOutletNode
    hw_pump.addToNode(hw_supply_inlet_node)
    hw_loop.addSupplyBranchForComponent(boiler)
    hw_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
    hw_supply_outlet_pipe.addToNode(hw_supply_outlet_node)

    # Add a setpoint manager to control the
    # hot water to a constant temperature    
    hw_t_c = OpenStudio::convert(153,"F","C").get
    hw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    hw_t_sch.setName("HW Temp")
    hw_t_sch.defaultDaySchedule().setName("HW Temp Default")
    hw_t_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),hw_t_c)
    hw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,hw_t_sch)
    hw_t_stpt_manager.addToNode(hw_supply_outlet_node)
    
    # Chilled Water Plant

    chw_loop = OpenStudio::Model::PlantLoop.new(model)
    chw_loop.setName("Chilled Water Loop")
    chw_sizing_plant = chw_loop.sizingPlant
    chw_sizing_plant.setLoopType("Cooling")
    chw_sizing_plant.setDesignLoopExitTemperature(7.22) #TODO units
    chw_sizing_plant.setLoopDesignTemperatureDifference(6.67)    

    chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    chiller = OpenStudio::Model::ChillerElectricEIR.new(model)
    
    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    chw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
                                                        
    # Add the components to the chilled water loop
    chw_supply_inlet_node = chw_loop.supplyInletNode
    chw_supply_outlet_node = chw_loop.supplyOutletNode
    chw_pump.addToNode(chw_supply_inlet_node)
    chw_loop.addSupplyBranchForComponent(chiller)
    chw_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
    chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

    # Add a setpoint manager to control the
    # chilled water to a constant temperature    
    chw_t_c = OpenStudio::convert(44,"F","C").get
    chw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    chw_t_sch.setName("CHW Temp")
    chw_t_sch.defaultDaySchedule().setName("CHW Temp Default")
    chw_t_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),chw_t_c)
    chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,chw_t_sch)
    chw_t_stpt_manager.addToNode(chw_supply_outlet_node)   
    
    schedules = Hash.new
    model.getScheduleFixedIntervals.each do |schedule|
      building = schedule.name.to_s.split[0]
      schedule_name = schedule.name.to_s.split[1..-1].join(" ")
      unless schedules.keys.include? building
        schedules[building] = Hash.new
      end
      schedules[building][schedule_name] = [schedule, schedule.comment.split(" = ")[1].to_f]
    end
    
    schedules.each do |building, schedule|

      load_profile_plant = OpenStudio::Model::LoadProfilePlant.new(model)
      load_profile_plant.setName("#{building} Heating Load Profile")
      load_profile_plant.setLoadSchedule(schedule["District Heating Hot Water Rate"][0])
      load_profile_plant.setPeakFlowRate(schedule["District Heating Mass Flow Rate"][1])
      load_profile_plant.setFlowRateFractionSchedule(schedule["District Heating Mass Flow Rate"][0])
      hw_loop.addDemandBranchForComponent(load_profile_plant)
    
      load_profile_plant = OpenStudio::Model::LoadProfilePlant.new(model)
      load_profile_plant.setName("#{building} Cooling Load Profile")
      load_profile_plant.setLoadSchedule(schedule["District Cooling Chilled Water Rate"][0])
      load_profile_plant.setPeakFlowRate(schedule["District Cooling Mass Flow Rate"][1])
      load_profile_plant.setFlowRateFractionSchedule(schedule["District Cooling Mass Flow Rate"][0])
      chw_loop.addDemandBranchForComponent(load_profile_plant)
    
    end
    
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    system_type = runner.getStringArgumentValue("system_type", user_arguments)
    
    if system_type == "None"
      runner.registerAsNotApplicable("NA.")
    elsif system_type == "Central Hot and Chilled Water"
      # todo: check commercial vs residential
      add_system_7_commercial(model)
    end

    return true

  end
  
end

# register the measure to be used by the application
AddDistrictSystem.new.registerWithApplication
