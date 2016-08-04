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
    
    # System Type 7: VAV w/ Reheat
    # This measure creates:
    # a single hot water loop with a natural gas boiler for the building
    # a single chilled water loop with water cooled chiller for the building
    # a single condenser water loop for heat rejection from the chiller
    # a VAV system w/ hot water heating, chilled water cooling, and 
    # hot water reheat for each story of the building
    
    always_on = model.alwaysOnDiscreteSchedule

    # Hot Water Plant

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    hw_loop.setName("Hot Water Loop for VAV with Reheat")
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
    chw_loop.setName("Chilled Water Loop for VAV with Reheat")
    chw_sizing_plant = chw_loop.sizingPlant
    chw_sizing_plant.setLoopType("Cooling")
    chw_sizing_plant.setDesignLoopExitTemperature(7.22) #TODO units
    chw_sizing_plant.setLoopDesignTemperatureDifference(6.67)    

    chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    
    chw_hx = OpenStudio::Model::HeatExchangerFluidToFluid.new(model)

    chw_hx_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
        
    chw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)                                                    
                                                        
    # Add the components to the chilled water loop
    chw_supply_inlet_node = chw_loop.supplyInletNode
    chw_supply_outlet_node = chw_loop.supplyOutletNode
    chw_pump.addToNode(chw_supply_inlet_node)
    chw_loop.addSupplyBranchForComponent(chw_hx)
    chw_loop.addSupplyBranchForComponent(chw_hx_bypass_pipe)
    chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

    # Add a setpoint manager to control the
    # chilled water to a constant temperature    
    chw_t_c = OpenStudio::convert(44,"F","C").get
    chw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    chw_t_sch.setName("CHW Temp")
    chw_t_sch.defaultDaySchedule().setName("HW Temp Default")
    chw_t_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),chw_t_c)
    chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,chw_t_sch)
    chw_t_stpt_manager.addToNode(chw_supply_outlet_node)  
      
    # District Chilled Water Loop
    
    cw_loop = OpenStudio::Model::PlantLoop.new(model)
    cw_loop.setName("District Chilled Water Loop")
    cw_sizing_plant = cw_loop.sizingPlant
    cw_sizing_plant.setLoopType("Cooling")
    cw_sizing_plant.setDesignLoopExitTemperature(chw_t_c) #TODO check value
    cw_sizing_plant.setLoopDesignTemperatureDifference(5.6)  #TODO check value   

    cw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    
    district_cooling = OpenStudio::Model::DistrictCooling.new(model)

    clg_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
        
    cw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)                                                    
                                                        
    # Add the components to the condenser water loop
    cw_supply_inlet_node = cw_loop.supplyInletNode
    cw_supply_outlet_node = cw_loop.supplyOutletNode
    cw_pump.addToNode(cw_supply_inlet_node)
    cw_loop.addSupplyBranchForComponent(district_cooling)
    cw_loop.addSupplyBranchForComponent(clg_bypass_pipe)
    cw_supply_outlet_pipe.addToNode(cw_supply_outlet_node)
    cw_loop.addDemandBranchForComponent(chw_hx)

    # Add a setpoint manager to control the
    chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,chw_t_sch)
    chw_t_stpt_manager.addToNode(cw_supply_outlet_node)  
    
    # Make a Packaged VAV w/ PFP Boxes for each story of the building
    model.getBuildingStorys.sort.each do |story|
          
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName("VAV with Reheat")
      sizingSystem = air_loop.sizingSystem
      sizingSystem.setCentralCoolingDesignSupplyAirTemperature(12.8)
      sizingSystem.setCentralHeatingDesignSupplyAirTemperature(12.8)    
      
      fan = OpenStudio::Model::FanVariableVolume.new(model,always_on)
      fan.setPressureRise(500)

      htg_coil = OpenStudio::Model::CoilHeatingWater.new(model,always_on)
      hw_loop.addDemandBranchForComponent(htg_coil)

      clg_coil = OpenStudio::Model::CoilCoolingWater.new(model,always_on)
      chw_loop.addDemandBranchForComponent(clg_coil)
      
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)      
      
      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode
      supply_outlet_node = air_loop.supplyOutletNode    
      fan.addToNode(supply_inlet_node)
      htg_coil.addToNode(supply_inlet_node)
      clg_coil.addToNode(supply_inlet_node)
      oa_system.addToNode(supply_inlet_node)    
      
      # Add a setpoint manager to control the
      # supply air to a constant temperature    
      sat_c = OpenStudio::convert(55,"F","C").get
      sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      sat_sch.setName("Supply Air Temp")
      sat_sch.defaultDaySchedule().setName("Supply Air Temp Default")
      sat_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),sat_c)
      sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,sat_sch)
      sat_stpt_manager.addToNode(supply_outlet_node)

      # Get all zones on this story
      zones = []
      story.spaces.each do |space|
        if space.thermalZone.is_initialized
          zones << space.thermalZone.get
        end      
      end 
      
      # Make a VAV terminal with HW reheat for each zone on this story
      # and hook the reheat coil to the HW loop
      zones.each do |zone|
        reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model,always_on)
        hw_loop.addDemandBranchForComponent(reheat_coil)
        vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model,always_on,reheat_coil)
        air_loop.addBranchForZone(zone,vav_terminal.to_StraightComponent)
      end   
    
    end # next story  
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
