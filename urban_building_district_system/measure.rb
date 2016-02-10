# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

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
    
    unless district_system_type == "Conventional"
        return false
    end

    return true
    
    runner.registerInfo("Removing existing HVAC.")
    
    airloops = model.getAirLoopHVACs
    plantLoops = model.getPlantLoops
    zones = model.getThermalZones

	# remove all zone equipment except zone exhaust fans
    zones.each do |zone|
		zone.equipment.each do |equip|
			if equip.to_FanZoneExhaust.is_initialized #or (equip.to_ZoneHVACUnitHeater.is_initialized and zone.get.equipment.size == 1)
			else  
                equip.remove
                runner.registerInfo("Removed #{equip.name} from #{zone.name}.")
			end
		end
	end
    	
    # remove an air loop if it's empty
    airloops.each do |air_loop|
		air_loop.thermalZones.each do |airZone|
			air_loop.removeBranchForZone(airZone)
            runner.registerInfo("Removed branch for zone #{airZone.name} from #{air_loop.name}.")
		end
		if air_loop.thermalZones.empty?
			air_loop.remove
            runner.registerInfo("Removed air loop #{air_loop.name}.")
		end
    end
   
    # remove plant loops
    plantLoops.each do |plantLoop|
		plantLoop.remove
		runner.registerInfo("Removed plant loop #{plantLoop.name}.")
	end
    
    runner.registerInfo("Adding district system.")
    
    # HOT WATER LOOP
    hot_water_plant = OpenStudio::Model::PlantLoop.new(model)
    hot_water_plant.setName("New Hot Water Loop")
    hot_water_plant.setMaximumLoopTemperature(100)
    hot_water_plant.setMinimumLoopTemperature(10)
    loop_sizing = hot_water_plant.sizingPlant
    loop_sizing.setLoopType("Heating")
    loop_sizing.setDesignLoopExitTemperature(82)
    loop_sizing.setLoopDesignTemperatureDifference(11)
    # create a pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setRatedPumpHead(119563) #Pa
    pump.setMotorEfficiency(0.9)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
    # create a boiler
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    boiler.setNominalThermalEfficiency(0.9)
    # create a scheduled setpoint manager
    # setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model,hot_water_setpoint_schedule)
    # create a supply bypass pipe
    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a supply outlet pipe
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand bypass pipe
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand inlet pipe
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand outlet pipe
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # connect components to plant loop
    # supply side components
    hot_water_plant.addSupplyBranchForComponent(boiler)
    hot_water_plant.addSupplyBranchForComponent(pipe_supply_bypass)
    pump.addToNode(hot_water_plant.supplyInletNode)
    pipe_supply_outlet.addToNode(hot_water_plant.supplyOutletNode)
    # setpoint_manager_scheduled.addToNode(hot_water_plant.supplyOutletNode)
    # demand side components (water coils are added as they are added to airloops and zoneHVAC)
    hot_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet.addToNode(hot_water_plant.demandInletNode)
    pipe_demand_outlet.addToNode(hot_water_plant.demandOutletNode)    
    
    # CHILLED WATER LOOP
    chilled_water_plant = OpenStudio::Model::PlantLoop.new(model)
    chilled_water_plant.setName("New Chilled Water Loop")
    chilled_water_plant.setMaximumLoopTemperature(98)
    chilled_water_plant.setMinimumLoopTemperature(1)
    loop_sizing = chilled_water_plant.sizingPlant
    loop_sizing.setLoopType("Cooling")
    loop_sizing.setDesignLoopExitTemperature(6.7)
    loop_sizing.setLoopDesignTemperatureDifference(6.7)
    # create a pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setRatedPumpHead(149453) #Pa
    pump.setMotorEfficiency(0.9)
    pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
    pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
    pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
    # create a chiller
      # create clgCapFuncTempCurve
      clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
      clgCapFuncTempCurve.setCoefficient1Constant(1.05E+00)
      clgCapFuncTempCurve.setCoefficient2x(3.36E-02)
      clgCapFuncTempCurve.setCoefficient3xPOW2(2.15E-04)
      clgCapFuncTempCurve.setCoefficient4y(-5.18E-03)
      clgCapFuncTempCurve.setCoefficient5yPOW2(-4.42E-05)
      clgCapFuncTempCurve.setCoefficient6xTIMESY(-2.15E-04)
      clgCapFuncTempCurve.setMinimumValueofx(0)
      clgCapFuncTempCurve.setMaximumValueofx(20)
      clgCapFuncTempCurve.setMinimumValueofy(0)
      clgCapFuncTempCurve.setMaximumValueofy(50)
      # create eirFuncTempCurve
      eirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
      eirFuncTempCurve.setCoefficient1Constant(5.83E-01)
      eirFuncTempCurve.setCoefficient2x(-4.04E-03)
      eirFuncTempCurve.setCoefficient3xPOW2(4.68E-04)
      eirFuncTempCurve.setCoefficient4y(-2.24E-04)
      eirFuncTempCurve.setCoefficient5yPOW2(4.81E-04)
      eirFuncTempCurve.setCoefficient6xTIMESY(-6.82E-04)
      eirFuncTempCurve.setMinimumValueofx(0)
      eirFuncTempCurve.setMaximumValueofx(20)
      eirFuncTempCurve.setMinimumValueofy(0)
      eirFuncTempCurve.setMaximumValueofy(50)
      # create eirFuncPlrCurve
      eirFuncPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
      eirFuncPlrCurve.setCoefficient1Constant(4.19E-02)
      eirFuncPlrCurve.setCoefficient2x(6.25E-01)
      eirFuncPlrCurve.setCoefficient3xPOW2(3.23E-01)
      eirFuncPlrCurve.setMinimumValueofx(0)
      eirFuncPlrCurve.setMaximumValueofx(1.2)
      # construct chiller
      chiller = OpenStudio::Model::ChillerElectricEIR.new(model,clgCapFuncTempCurve,eirFuncTempCurve,eirFuncPlrCurve)
      chiller.setReferenceCOP(2.93)
      chiller.setCondenserType("AirCooled")
      chiller.setChillerFlowMode("ConstantFlow")
    # create a scheduled setpoint manager
    # setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model,chilled_water_setpoint_schedule)
    # create a supply bypass pipe
    pipe_supply_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a supply outlet pipe
    pipe_supply_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand bypass pipe
    pipe_demand_bypass = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand inlet pipe
    pipe_demand_inlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # create a demand outlet pipe
    pipe_demand_outlet = OpenStudio::Model::PipeAdiabatic.new(model)
    # connect components to plant loop
    # supply side components
    chilled_water_plant.addSupplyBranchForComponent(chiller)
    chilled_water_plant.addSupplyBranchForComponent(pipe_supply_bypass)
    pump.addToNode(chilled_water_plant.supplyInletNode)
    pipe_supply_outlet.addToNode(chilled_water_plant.supplyOutletNode)
    # setpoint_manager_scheduled.addToNode(chilled_water_plant.supplyOutletNode)
    # demand side components (water coils are added as they are added to airloops and ZoneHVAC)
    chilled_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
    pipe_demand_inlet.addToNode(chilled_water_plant.demandInletNode)
    pipe_demand_outlet.addToNode(chilled_water_plant.demandOutletNode)    
    
    # CONDENSER WATER LOOP
    
    # AIR LOOP
    
    return true

  end
  
end

# register the measure to be used by the application
UrbanBuildingDistrictSystem.new.registerWithApplication
