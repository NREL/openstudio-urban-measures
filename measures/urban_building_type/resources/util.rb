require 'fileutils'

# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model 

  def add_zone_water_to_air_hp(loop, thermal_zones)
  
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding zone water-to-air heat pump.")

    water_to_air_hp_systems = []
    thermal_zones.each do |zone|
    
      supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, self.alwaysOnDiscreteSchedule)
  
      htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(self)
      htg_coil.setName("Water-to-Air HP Htg Coil")
      htg_coil.setRatedHeatingCoefficientofPerformance(4.2)
      htg_coil.setHeatingCapacityCoefficient1(0.237847462869254)
      htg_coil.setHeatingCapacityCoefficient2(-3.35823796081626)
      htg_coil.setHeatingCapacityCoefficient3(3.80640467406376)
      htg_coil.setHeatingCapacityCoefficient4(0.179200417311554)
      htg_coil.setHeatingCapacityCoefficient5(0.12860719846082)
      htg_coil.setHeatingPowerConsumptionCoefficient1(-3.79175529243238)
      htg_coil.setHeatingPowerConsumptionCoefficient2(3.38799239505527)
      htg_coil.setHeatingPowerConsumptionCoefficient3(1.5022612076303)
      htg_coil.setHeatingPowerConsumptionCoefficient4(-0.177653510577989)
      htg_coil.setHeatingPowerConsumptionCoefficient5(-0.103079864171839)

      loop.addDemandBranchForComponent(htg_coil)        

      clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(self)
      clg_coil.setName("Water-to-Air HP Clg Coil")
      clg_coil.setRatedCoolingCoefficientofPerformance(3.4)
      clg_coil.setTotalCoolingCapacityCoefficient1(-4.30266987344639)
      clg_coil.setTotalCoolingCapacityCoefficient2(7.18536990534372)
      clg_coil.setTotalCoolingCapacityCoefficient3(-2.23946714486189)
      clg_coil.setTotalCoolingCapacityCoefficient4(0.139995928440879)
      clg_coil.setTotalCoolingCapacityCoefficient5(0.102660179888915)
      clg_coil.setSensibleCoolingCapacityCoefficient1(6.0019444814887)
      clg_coil.setSensibleCoolingCapacityCoefficient2(22.6300677244073)
      clg_coil.setSensibleCoolingCapacityCoefficient3(-26.7960783730934)
      clg_coil.setSensibleCoolingCapacityCoefficient4(-1.72374720346819)
      clg_coil.setSensibleCoolingCapacityCoefficient5(0.490644802367817)
      clg_coil.setSensibleCoolingCapacityCoefficient6(0.0693119353468141)
      clg_coil.setCoolingPowerConsumptionCoefficient1(-5.67775976415698)
      clg_coil.setCoolingPowerConsumptionCoefficient2(0.438988156976704)
      clg_coil.setCoolingPowerConsumptionCoefficient3(5.845277342193)
      clg_coil.setCoolingPowerConsumptionCoefficient4(0.141605667000125)
      clg_coil.setCoolingPowerConsumptionCoefficient5(-0.168727936032429)        
  
      loop.addDemandBranchForComponent(clg_coil)    
  
      # add fan
      fan = OpenStudio::Model::FanOnOff.new(self, self.alwaysOnDiscreteSchedule)
      fan.setName("#{zone.name} Water-to_Air HP Fan")
      fan_static_pressure_in_h2o = 1.33
      fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, "inH_{2}O","Pa").get
      fan.setPressureRise(fan_static_pressure_pa)
      fan.setFanEfficiency(0.52)
      fan.setMotorEfficiency(0.8)  
  
      water_to_air_hp_system = OpenStudio::Model::ZoneHVACWaterToAirHeatPump.new(self, 
                                                                                 self.alwaysOnDiscreteSchedule, 
                                                                                 fan, 
                                                                                 htg_coil, 
                                                                                 clg_coil,
                                                                                 supplemental_htg_coil)
                                                                              
      water_to_air_hp_system.addToThermalZone(zone)

      water_to_air_hp_systems << water_to_air_hp_system
      
    end

    return water_to_air_hp_systems                                                                                
      
  end
  
  def add_zone_erv(thermal_zones)
  
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding zone erv.")
  
    erv_systems = []
    thermal_zones.each do |zone|

      supply_fan = OpenStudio::Model::FanOnOff.new(self)
      supply_fan.setFanEfficiency(OpenStudio::convert(300.0 / 0.3,"cfm","m^3/s").get)
      supply_fan.setPressureRise(300.0)
      # supply_fan.setMaximumFlowRate(OpenStudio::convert(mech_vent.whole_house_vent_rate,"cfm","m^3/s").get)
      supply_fan.setMotorEfficiency(1)
      supply_fan.setMotorInAirstreamFraction(1)

      exhaust_fan = OpenStudio::Model::FanOnOff.new(self)
      exhaust_fan.setFanEfficiency(OpenStudio::convert(300.0 / 0.3,"cfm","m^3/s").get)
      exhaust_fan.setPressureRise(300.0)
      # exhaust_fan.setMaximumFlowRate(OpenStudio::convert(mech_vent.whole_house_vent_rate,"cfm","m^3/s").get)
      exhaust_fan.setMotorEfficiency(1)
      exhaust_fan.setMotorInAirstreamFraction(0)

      erv_controller = OpenStudio::Model::ZoneHVACEnergyRecoveryVentilatorController.new(self)
      erv_controller.setExhaustAirTemperatureLimit("NoExhaustAirTemperatureLimit")
      erv_controller.setExhaustAirEnthalpyLimit("NoExhaustAirEnthalpyLimit")
      erv_controller.setTimeofDayEconomizerFlowControlSchedule(self.alwaysOnDiscreteSchedule)
      erv_controller.setHighHumidityControlFlag(false)

      heat_exchanger = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(self)
      # heat_exchanger.setNominalSupplyAirFlowRate(OpenStudio::convert(mech_vent.whole_house_vent_rate,"cfm","m^3/s").get)
      # heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(mech_vent.MechVentHXCoreSensibleEffectiveness)
      # heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(mech_vent.MechVentLatentEffectiveness)
      # heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(mech_vent.MechVentHXCoreSensibleEffectiveness)
      # heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(mech_vent.MechVentLatentEffectiveness)
      # heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(mech_vent.MechVentHXCoreSensibleEffectiveness)
      # heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(mech_vent.MechVentLatentEffectiveness)
      # heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(mech_vent.MechVentHXCoreSensibleEffectiveness)
      # heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(mech_vent.MechVentLatentEffectiveness)        

      zone_hvac = OpenStudio::Model::ZoneHVACEnergyRecoveryVentilator.new(self, heat_exchanger, supply_fan, exhaust_fan)
      zone_hvac.setController(erv_controller)
      # zone_hvac.setSupplyAirFlowRate(OpenStudio::convert(mech_vent.whole_house_vent_rate,"cfm","m^3/s").get)
      # zone_hvac.setExhaustAirFlowRate(OpenStudio::convert(mech_vent.whole_house_vent_rate,"cfm","m^3/s").get)      
      zone_hvac.addToThermalZone(zone)      
      
      erv_systems << zone_hvac
    
    end
    
    return erv_systems
    
  end  
  
  # Creates a DOAS system with fan coil units
  # for each zone.
  #
  # @param standard [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [String] hot water loop to connect heating and zone fan coils to
  # @param chilled_water_loop [String] chilled water loop to connect cooling coil to
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule, 
  # or nil in which case will be defaulted to always open
  # @param fan_max_flow_rate [Double] fan maximum flow rate, in m^3/s.
  # if nil, this value will be autosized.
  # @param economizer_control_type [String] valid choices are
  # FixedDryBulb, 
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting DOAS air loop
  def add_doas(standard, 
               sys_name, 
               hot_water_loop, 
               chilled_water_loop,
               thermal_zones,
               hvac_op_sch,
               oa_damper_sch,
               fan_max_flow_rate,
               economizer_control_type,
               building_type=nil,
               energy_recovery=false) 
  
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding DOAS system for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio::logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = self.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = self.add_schedule(hvac_op_sch)
    end
    
    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = self.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = self.add_schedule(oa_damper_sch)
    end

    # DOAS
    air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} DOAS Air Loop HVAC")
    else
      air_loop.setName("DOAS Air Loop HVAC")
    end
    air_loop.setNightCycleControlType('CycleOnAny')
    # modify system sizing properties
    sizing_system = air_loop.sizingSystem
    # set central heating and cooling temperatures for sizing
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(12.8)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(16.7)   #ML OS default is 16.7
    sizing_system.setSizingOption("Coincident")
    # load specification
    sizing_system.setSystemOutdoorAirMethod("ZoneSum")                #ML OS default is ZoneSum
    sizing_system.setTypeofLoadtoSizeOn("Ventilation")      # DOAS
    sizing_system.setAllOutdoorAirinCooling(true)           # DOAS
    sizing_system.setAllOutdoorAirinHeating(true)           # DOAS
    sizing_system.setMinimumSystemAirFlowRatio(0.3)         # No DCV

    # set availability schedule
    air_loop.setAvailabilitySchedule(hvac_op_sch)
    airloop_supply_inlet = air_loop.supplyInletNode

    # create air loop fan
    # constant speed fan
    fan = OpenStudio::Model::FanConstantVolume.new(self, self.alwaysOnDiscreteSchedule)
    fan.setName("DOAS fan")
    fan.setFanEfficiency(0.58175)
    fan.setPressureRise(622.5) #Pa
    if fan_max_flow_rate != nil
      fan.setMaximumFlowRate(fan_max_flow_rate)
    else
      fan.autosizeMaximumFlowRate
    end
    fan.setMotorEfficiency(0.895)
    fan.setMotorInAirstreamFraction(1.0)
    fan.setEndUseSubcategory("DOAS Fans")
    fan.addToNode(airloop_supply_inlet)

    # create heating coil
    # water coil
    heating_coil = OpenStudio::Model::CoilHeatingWater.new(self, self.alwaysOnDiscreteSchedule)
    hot_water_loop.addDemandBranchForComponent(heating_coil)
    heating_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
    heating_coil.addToNode(airloop_supply_inlet)
    heating_coil.controllerWaterCoil.get.setControllerConvergenceTolerance(0.0001)

    # create cooling coil
    # water coil
    cooling_coil = OpenStudio::Model::CoilCoolingWater.new(self, self.alwaysOnDiscreteSchedule)
    chilled_water_loop.addDemandBranchForComponent(cooling_coil)
    cooling_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
    cooling_coil.addToNode(airloop_supply_inlet)

    # create controller outdoor air
    controller_OA = OpenStudio::Model::ControllerOutdoorAir.new(self)
    controller_OA.setName("DOAS OA Controller")
    controller_OA.setEconomizerControlType(economizer_control_type)
    controller_OA.setMinimumLimitType('FixedMinimum')
    controller_OA.setMinimumOutdoorAirSchedule(oa_damper_sch)
    controller_OA.resetEconomizerMaximumLimitDryBulbTemperature
    # TODO: Yixing read the schedule from the Prototype Input
    if building_type == "LargeHotel"
      controller_OA.setMinimumFractionofOutdoorAirSchedule(self.add_schedule("HotelLarge FLR_3_DOAS_OAminOAFracSchedule"))
    end
    controller_OA.resetEconomizerMaximumLimitEnthalpy
    controller_OA.resetMaximumFractionofOutdoorAirSchedule
    controller_OA.resetEconomizerMinimumLimitDryBulbTemperature

    # create ventilation schedules and assign to OA controller
    controller_OA.setHeatRecoveryBypassControlType("BypassWhenWithinEconomizerLimits")

    # create outdoor air system
    system_OA = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, controller_OA)
    system_OA.addToNode(airloop_supply_inlet)

    if energy_recovery
      # Get the OA system and its outboard OA node
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      oa_node = oa_system.outboardOANode.get
      
      # Create the ERV and set its properties
      erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(self)
      erv.addToNode(oa_node)	
      erv.setHeatExchangerType("Rotary")
      # TODO Come up with scheme for estimating power of ERV motor wheel
      # which might require knowing airlow (like prototype buildings do).
      # erv.setNominalElectricPower(value_new)
      erv.setEconomizerLockout(true)
      erv.setSupplyAirOutletTemperatureControl(false)
      
      erv.setSensibleEffectivenessat100HeatingAirFlow(0.76)
      erv.setSensibleEffectivenessat75HeatingAirFlow(0.81)
      erv.setLatentEffectivenessat100HeatingAirFlow(0.68)
      erv.setLatentEffectivenessat75HeatingAirFlow(0.73)      
      
      erv.setSensibleEffectivenessat100CoolingAirFlow(0.76)
      erv.setSensibleEffectivenessat75CoolingAirFlow(0.81)
      erv.setLatentEffectivenessat100CoolingAirFlow(0.68)
      erv.setLatentEffectivenessat75CoolingAirFlow(0.73)

      # Increase fan pressure caused by the ERV
      fans = []
      fans += air_loop.supplyComponents("OS:Fan:VariableVolume".to_IddObjectType)
      fans += air_loop.supplyComponents("OS:Fan:ConstantVolume".to_IddObjectType)
      if fans.size > 0
        if fans[0].to_FanConstantVolume.is_initialized
          fans[0].to_FanConstantVolume.get.setPressureRise(OpenStudio.convert(1.0,"inH_{2}O","Pa").get)
        elsif fans[0].to_FanVariableVolume.is_initialized
          fans[0].to_FanVariableVolume.get.setPressureRise(OpenStudio.convert(1.0,"inH_{2}O","Pa").get)
        end
      end
    end
    
    # create scheduled setpoint manager for airloop
    # DOAS or VAV for cooling and not ventilation
    setpoint_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(self)
    setpoint_manager.setControlVariable('Temperature')
    setpoint_manager.setSetpointatOutdoorLowTemperature(15.5)
    setpoint_manager.setOutdoorLowTemperature(15.5)
    setpoint_manager.setSetpointatOutdoorHighTemperature(12.8)
    setpoint_manager.setOutdoorHighTemperature(21)

    # connect components to airloop
    # find the supply inlet node of the airloop

    # add setpoint manager to supply equipment outlet node
    setpoint_manager.addToNode(air_loop.supplyOutletNode)

    # add thermal zones to airloop
    thermal_zones.each do |zone|
      zone_name = zone.name.to_s

      zone_sizing = zone.sizingZone
      zone_sizing.setZoneCoolingDesignSupplyAirTemperature(12.8)
      zone_sizing.setZoneHeatingDesignSupplyAirTemperature(40)
      zone_sizing.setCoolingDesignAirFlowMethod("DesignDayWithLimit")
      zone_sizing.setHeatingDesignAirFlowMethod("DesignDay")

      # make an air terminal for the zone
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(self, self.alwaysOnDiscreteSchedule)
      air_terminal.setName(zone_name + "Air Terminal")

      fan_coil_cooling_coil = OpenStudio::Model::CoilCoolingWater.new(self, self.alwaysOnDiscreteSchedule)
      fan_coil_cooling_coil.setName(zone_name + "FCU Cooling Coil")
      chilled_water_loop.addDemandBranchForComponent(fan_coil_cooling_coil)
      fan_coil_cooling_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)

      fan_coil_heating_coil = OpenStudio::Model::CoilHeatingWater.new(self, self.alwaysOnDiscreteSchedule)
      fan_coil_heating_coil.setName(zone_name + "FCU Heating Coil")
      hot_water_loop.addDemandBranchForComponent(fan_coil_heating_coil)
      fan_coil_heating_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)

      fan_coil_fan = OpenStudio::Model::FanOnOff.new(self, self.alwaysOnDiscreteSchedule)
      fan_coil_fan.setName(zone_name + " Fan Coil fan")
      fan_coil_fan.setFanEfficiency(0.16)
      fan_coil_fan.setPressureRise(270.9) #Pa
      fan_coil_fan.autosizeMaximumFlowRate
      fan_coil_fan.setMotorEfficiency(0.29)
      fan_coil_fan.setMotorInAirstreamFraction(1.0)
      fan_coil_fan.setEndUseSubcategory("FCU Fans")

      fan_coil = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(self, self.alwaysOnDiscreteSchedule,
                                                            fan_coil_fan, fan_coil_cooling_coil, fan_coil_heating_coil)
      fan_coil.setName(zone_name + "FCU")
      fan_coil.setCapacityControlMethod("CyclingFan")
      fan_coil.autosizeMaximumSupplyAirFlowRate
      fan_coil.setMaximumOutdoorAirFlowRate(0)
      fan_coil.addToThermalZone(zone)

      # attach new terminal to the zone and to the airloop
      air_loop.addBranchForZone(zone, air_terminal.to_StraightComponent)
    end
    
    return air_loop
    
  end
  
  # Creates a hot water loop with one boiler
  # and add it to the model.
  #
  # @param boiler_fuel_type [String] valid choices are Electricity, Gas, PropaneGas, FuelOil#1, FuelOil#2
  # @return [OpenStudio::Model::PlantLoop] the resulting hot water loop  
  def add_hw_loop(boiler_fuel_type, building_type=nil, ambient_loop=nil)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding hot water loop.")
  
    #hot water loop
    loop = OpenStudio::Model::PlantLoop.new(self)
    loop.setName('Hot Water Loop')
    loop.setMinimumLoopTemperature(10)

    #hot water loop controls
    # TODO: Yixing check other building types and add the parameter to the prototype input if more values comes out.
    if building_type == "LargeHotel"
      hw_temp_f = 140 #HW setpoint 140F
    else
      hw_temp_f = 180 #HW setpoint 180F
    end

    hw_delta_t_r = 20 #20F delta-T
    hw_temp_c = OpenStudio.convert(hw_temp_f,'F','C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r,'R','K').get
    hw_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    hw_temp_sch.setName("Hot Water Loop Temp - #{hw_temp_f}F")
    hw_temp_sch.defaultDaySchedule.setName("Hot Water Loop Temp - #{hw_temp_f}F Default")
    hw_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),hw_temp_c)
    hw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self,hw_temp_sch)
    hw_stpt_manager.setName("Hot water loop setpoint manager")
    hw_stpt_manager.addToNode(loop.supplyOutletNode)
    sizing_plant = loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(hw_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(hw_delta_t_k)

    #hot water pump
    hw_pump = OpenStudio::Model::PumpVariableSpeed.new(self)
    hw_pump.setName('Hot Water Loop Pump')
    hw_pump_head_ft_h2o = 60.0
    hw_pump_head_press_pa = OpenStudio.convert(hw_pump_head_ft_h2o, 'ftH_{2}O','Pa').get
    hw_pump.setRatedPumpHead(hw_pump_head_press_pa)
    hw_pump.setMotorEfficiency(0.9)
    hw_pump.setFractionofMotorInefficienciestoFluidStream(0)
    hw_pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
    hw_pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
    hw_pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
    hw_pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
    hw_pump.setPumpControlType('Intermittent')
    hw_pump.addToNode(loop.supplyInletNode)

    if boiler_fuel_type != 'HeatPump' 
      #boiler
      boiler_max_t_f = 203
      boiler_max_t_c = OpenStudio.convert(boiler_max_t_f,'F','C').get
      boiler = OpenStudio::Model::BoilerHotWater.new(self)
      boiler.setName('Hot Water Loop Boiler')
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')
      boiler.setFuelType(boiler_fuel_type)
      boiler.setDesignWaterOutletTemperature(hw_temp_c)
      boiler.setNominalThermalEfficiency(0.78)
      boiler.setMaximumPartLoadRatio(1.2)
      boiler.setWaterOutletUpperTemperatureLimit(boiler_max_t_c)
      boiler.setBoilerFlowMode('LeavingSetpointModulated')
      loop.addSupplyBranchForComponent(boiler)

      if building_type == "LargeHotel"
        boiler.setEfficiencyCurveTemperatureEvaluationVariable("LeavingBoiler")
        boiler.setDesignWaterOutletTemperature(81)
        boiler.setMaximumPartLoadRatio(1.2)
        boiler.setSizingFactor(1.2)
        boiler.setWaterOutletUpperTemperatureLimit(95)
      end

      # TODO: Yixing. Add the temperature setpoint will cost the simulation with
      # thousands of Severe Errors. Need to figure this out later.
      #boiler_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self,hw_temp_sch)
      #boiler_stpt_manager.setName("Boiler outlet setpoint manager")
      #boiler_stpt_manager.addToNode(boiler.outletModelObject.get.to_Node.get)
    else
      water_to_water_hp = OpenStudio::Model::HeatPumpWaterToWaterEquationFitHeating.new(self)
      loop.addSupplyBranchForComponent(water_to_water_hp)
      ambient_loop.addDemandBranchForComponent(water_to_water_hp)
    end

    #hot water loop pipes
    supply_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    loop.addSupplyBranchForComponent(supply_bypass_pipe)
    demand_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    loop.addDemandBranchForComponent(demand_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_outlet_pipe.addToNode(loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_inlet_pipe.addToNode(loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_outlet_pipe.addToNode(loop.demandOutletNode)

    return loop

  end  
  
  def add_district_hot_water_loop(boiler_fuel_type)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding district hot water loop.")
  
    loop = self.add_hw_loop(boiler_fuel_type)
  
    loop.supplyComponents.each do |supplyComponent|
      if supplyComponent.to_BoilerHotWater.is_initialized
        boiler = supplyComponent.to_BoilerHotWater.get
        loop.removeSupplyBranchWithComponent(boiler)
      end
    end
    district_heating = OpenStudio::Model::DistrictHeating.new(self)
    district_heating.setNominalCapacity(1000000000000) # large number; no autosizing
    loop.addSupplyBranchForComponent(district_heating)
    
    return loop
      
  end

  def add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess)
  
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding district chilled water loop.")
  
    loop = self.add_chw_loop(nil, chw_pumping_type, chiller_cooling_type, chiller_condenser_type,  chiller_compressor_type, chiller_capacity_guess)

    loop.supplyComponents.each do |supplyComponent|
      if supplyComponent.to_ChillerElectricEIR.is_initialized
        chiller = supplyComponent.to_ChillerElectricEIR.get
        loop.removeSupplyBranchWithComponent(chiller)
      end
    end
    district_cooling = OpenStudio::Model::DistrictCooling.new(self)
    district_cooling.setNominalCapacity(1000000000000) # large number; no autosizing
    loop.addSupplyBranchForComponent(district_cooling)
    
    return loop

  end

  def add_district_ambient_loop(lower_loop_temp_f, upper_loop_temp_f)
  
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding district ambient loop.")  
  
    # Ambient loop
    loop = OpenStudio::Model::PlantLoop.new(self)
    loop.setName('Ambient Loop')
    loop.setMaximumLoopTemperature(80)
    loop.setMinimumLoopTemperature(5)

    # Ambient loop controls
    amb_high_temp_f = lower_loop_temp_f # Supplemental heat below 65F
    amb_low_temp_f = upper_loop_temp_f # Supplemental cooling below 41F
    amb_temp_sizing_f = 102.2 #CW sized to deliver 102.2F
    amb_delta_t_r = 19.8 #19.8F delta-T

    amb_high_temp_c = OpenStudio.convert(amb_high_temp_f,'F','C').get
    amb_low_temp_c = OpenStudio.convert(amb_low_temp_f,'F','C').get
    amb_temp_sizing_c = OpenStudio.convert(amb_temp_sizing_f,'F','C').get
    amb_delta_t_k = OpenStudio.convert(amb_delta_t_r,'R','K').get

    amb_high_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    amb_high_temp_sch.setName("Ambient Loop High Temp - #{amb_high_temp_f}F")
    amb_high_temp_sch.defaultDaySchedule.setName("Ambient Loop High Temp - #{amb_high_temp_f}F Default")
    amb_high_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),amb_high_temp_c)

    amb_low_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    amb_low_temp_sch.setName("Ambient Loop Low Temp - #{amb_low_temp_f}F")
    amb_low_temp_sch.defaultDaySchedule.setName("Ambient Loop Low Temp - #{amb_low_temp_f}F Default")
    amb_low_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),amb_low_temp_c)

    amb_stpt_manager = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(self)
    amb_stpt_manager.setHighSetpointSchedule(amb_high_temp_sch)
    amb_stpt_manager.setLowSetpointSchedule(amb_low_temp_sch)
    amb_stpt_manager.addToNode(loop.supplyOutletNode)

    sizing_plant = loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(amb_temp_sizing_c)
    sizing_plant.setLoopDesignTemperatureDifference(amb_delta_t_k)

    # Ambient loop pump
    amb_pump = OpenStudio::Model::PumpVariableSpeed.new(self)
    amb_pump.setName('Ambient Loop Pump')
    amb_pump_head_ft_h2o = 60
    amb_pump_head_press_pa = OpenStudio.convert(amb_pump_head_ft_h2o, 'ftH_{2}O','Pa').get
    amb_pump.setRatedPumpHead(amb_pump_head_press_pa)
    amb_pump.setPumpControlType('Intermittent')
    amb_pump.addToNode(loop.supplyInletNode)

    # Cooling
    district_cooling = OpenStudio::Model::DistrictCooling.new(self)
    district_cooling.setNominalCapacity(1000000000000) # large number; no autosizing
    loop.addSupplyBranchForComponent(district_cooling)
    #### Add SPM Scheduled Dual Setpoint to outlet of Fluid Cooler so correct Plant Operation Scheme is generated
    amb_stpt_manager_2 = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(self)
    amb_stpt_manager_2.setHighSetpointSchedule(amb_high_temp_sch)
    amb_stpt_manager_2.setLowSetpointSchedule(amb_low_temp_sch)
    amb_stpt_manager_2.addToNode(district_cooling.outletModelObject.get.to_Node.get)

    # Heating
    district_heating = OpenStudio::Model::DistrictHeating.new(self)
    district_heating.setNominalCapacity(1000000000000) # large number; no autosizing
    loop.addSupplyBranchForComponent(district_heating)
    #### Add SPM Scheduled Dual Setpoint to outlet of Boiler so correct Plant Operation Scheme is generated
    amb_stpt_manager_3 = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(self)
    amb_stpt_manager_3.setHighSetpointSchedule(amb_high_temp_sch)
    amb_stpt_manager_3.setLowSetpointSchedule(amb_low_temp_sch)
    amb_stpt_manager_3.addToNode(district_heating.outletModelObject.get.to_Node.get)

    # Ambient water loop pipes
    supply_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_bypass_pipe.setName("#{loop.name} Supply Bypass")
    loop.addSupplyBranchForComponent(supply_bypass_pipe)

    demand_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_bypass_pipe.setName("#{loop.name} Demand Bypass")
    loop.addDemandBranchForComponent(demand_bypass_pipe)

    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_outlet_pipe.setName("#{loop.name} Supply Outlet")
    supply_outlet_pipe.addToNode(loop.supplyOutletNode)

    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_inlet_pipe.setName("#{loop.name} Demand Inlet")
    demand_inlet_pipe.addToNode(loop.demandInletNode)

    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_outlet_pipe.setName("#{loop.name} Demand Outlet")
    demand_outlet_pipe.addToNode(loop.demandOutletNode)
    
    return loop  
  
  end 
  
  # Modify add_hw_loop in Prototype.hvac_systems.rb
  # to add a new boiler type called "HeatPump"
  # Add a new optional arugment ambient_loop=nil at the end
  # If boiler_fuel_type == 'HeatPump'
  # Add a HeatPumpWaterToWaterEquationFitHeating in place of the boiler
  # Connect the other side of the heat upmp to the ambient loop 

  # For the water-cooled chiller, just use the add_chw method
  # and pass the ambient_loop into the condenser_loop argument
  def add_forced_air_on_ambient_loop(type)
    case type
    when 'Zone Water to Air HP w/ ERV'
      add_zone_water_to_air_hp
      add_zone_erv
    when 'Zone Water to Air HP w/ DOAS'
      add_zone_water_to_air_hp
      add_doas
    when 'VAV w/ Heat Pumps'
      hw_loop = add_hw_loop('HeatPump', ambient_loop)
      chw_loop = add_chw_loop(ambient_loop)
      add_vav_reheat(hw_loop, chw_loop)
    end

  end
  
  # Creates a VAV system with parallel fan powered boxes and adds it to the model.
  #
  # @param standard [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param chilled_water_loop [String] chilled water loop to connect cooling coil to
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule, 
  # or nil in which case will be defaulted to always open
  # @param vav_fan_efficiency [Double] fan total efficiency, including motor and impeller
  # @param vav_fan_motor_efficiency [Double] fan motor efficiency
  # @param vav_fan_pressure_rise [Double] fan pressure rise, in Pa  
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting VAV air loop
  def self.add_pvav_pfp_boxes(standard, 
                              sys_name, 
                              thermal_zones,
                              hvac_op_sch,
                              oa_damper_sch,
                              vav_fan_efficiency,
                              vav_fan_motor_efficiency,
                              vav_fan_pressure_rise,
                              building_type=nil)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PVAV with PFP Boxes and Reheat system for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio::logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = self.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = self.add_schedule(hvac_op_sch)
    end
    
    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = self.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = self.add_schedule(oa_damper_sch)
    end

    # control temps used across all air handlers
    clg_sa_temp_f = 55.04 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    preclg_sa_temp_f = 55.04 # Precool to 55F
    htg_sa_temp_f = 55.04 # Central deck htg temp 55F
    rht_sa_temp_f = 104 # VAV box reheat to 104F
    zone_htg_sa_temp_f = 104 # Zone heating design supply air temperature to 104 F
    
    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f,'F','C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f,'F','C').get
    preclg_sa_temp_c = OpenStudio.convert(preclg_sa_temp_f,'F','C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f,'F','C').get
    rht_sa_temp_c = OpenStudio.convert(rht_sa_temp_f,'F','C').get
    zone_htg_sa_temp_c = OpenStudio.convert(zone_htg_sa_temp_f,'F','C').get

    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),clg_sa_temp_c)

    #air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV with PFP Boxes and Reheat")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, sa_temp_sch)
    sa_stpt_manager.setName("#{thermal_zones.size} Zone VAV supply air setpoint manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    #air handler controls
    sizing_system = air_loop.sizingSystem
    sizing_system.setPreheatDesignTemperature(prehtg_sa_temp_c)
    sizing_system.setPrecoolDesignTemperature(preclg_sa_temp_c)
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_sa_temp_c)
    sizing_system.setSizingOption('Coincident')
    sizing_system.setAllOutdoorAirinCooling(false)
    sizing_system.setAllOutdoorAirinHeating(false)
    sizing_system.setSystemOutdoorAirMethod('ZoneSum')

    #fan
    fan = OpenStudio::Model::FanVariableVolume.new(self, self.alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.setFanEfficiency(vav_fan_efficiency)
    fan.setMotorEfficiency(vav_fan_motor_efficiency)
    fan.setPressureRise(vav_fan_pressure_rise)
    fan.setFanPowerMinimumFlowRateInputMethod('fraction')
    fan.setFanPowerMinimumFlowFraction(0.25)
    fan.addToNode(air_loop.supplyInletNode)
    fan.setEndUseSubcategory("VAV system Fans")

    #heating coil
    htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, self.alwaysOnDiscreteSchedule)
    htg_coil.setName("#{air_loop.name} Htg Coil")
    htg_coil.addToNode(air_loop.supplyInletNode)

    # Cooling coil
    clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(self)
    clg_coil.setName("#{air_loop.name} Clg Coil")
    clg_coil.addToNode(air_loop.supplyInletNode)

    #outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(self)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    #oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system need to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    #hook the VAV system to each zone
    thermal_zones.each do |zone|

      #reheat coil
      rht_coil = OpenStudio::Model::CoilHeatingElectric.new(self, self.alwaysOnDiscreteSchedule)
      rht_coil.setName("#{zone.name} Rht Coil")

      # terminal fan
      pfp_fan = OpenStudio::Model::FanConstantVolume.new(self, self.alwaysOnDiscreteSchedule)
      pfp_fan.setName("#{zone.name} PFP Term Fan")
      pfp_fan.setPressureRise(300)
      
      #parallel fan powered terminal
      pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(self, self.alwaysOnDiscreteSchedule, pfp_fan, rht_coil)
      pfp_terminal.setName("#{zone.name} PFP Term")
      air_loop.addBranchForZone(zone,pfp_terminal.to_StraightComponent)

      # Zone sizing
      # TODO Create general logic for cooling airflow method.
      # Large hotel uses design day with limit, school uses design day.
      sizing_zone = zone.sizingZone
      sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
      sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
      #sizing_zone.setZoneHeatingDesignSupplyAirTemperature(rht_sa_temp_c)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(zone_htg_sa_temp_c)

    end

    return air_loop

  end

end

class HelperMethods

  def self.zones_with_thermostats(thermal_zones)
      
    zones_with_thermostats = []
    thermal_zones.each do |thermal_zone|
      if thermal_zone.thermostat.is_initialized
        zones_with_thermostats << thermal_zone
      end
    end
      
    return zones_with_thermostats
      
  end

  def self.remove_all_hvac_equipment(model, runner)
      
    airloops = model.getAirLoopHVACs
    plantLoops = model.getPlantLoops
    thermal_zones = model.getThermalZones

    # remove all zone equipment except zone exhaust fans
    thermal_zones.each do |zone|
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
      remove = true
      supplyComponents = plantLoop.supplyComponents
      supplyComponents.each do |supplyComponent|
        if supplyComponent.to_WaterHeaterMixed.is_initialized or supplyComponent.to_WaterHeaterStratified.is_initialized # don't remove the dhw
          remove = false
        end
      end
      if remove
        plantLoop.remove
        runner.registerInfo("Removed plant loop #{plantLoop.name}.")
      end
    end
  end
  
end