

class HelperMethods

    def self.remove_existing_hvac_equipment(model, runner)
    
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
    
    end
    
    def self.create_hot_water_plant(model, runner, schedule)
    
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
        setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, schedule)
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
        setpoint_manager_scheduled.addToNode(hot_water_plant.supplyOutletNode)
        # demand side components (water coils are added as they are added to airloops and zoneHVAC)
        hot_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
        pipe_demand_inlet.addToNode(hot_water_plant.demandInletNode)
        pipe_demand_outlet.addToNode(hot_water_plant.demandOutletNode)

        # pass back hot water plant
        result = hot_water_plant
        return result
    
    end
    
    def self.create_radiant_hot_water_plant(model, runner, schedule)
    
        hot_water_plant = OpenStudio::Model::PlantLoop.new(model)
        hot_water_plant.setName("New Radiant Hot Water Loop")
        hot_water_plant.setMaximumLoopTemperature(100)
        hot_water_plant.setMinimumLoopTemperature(10)
        loop_sizing = hot_water_plant.sizingPlant
        loop_sizing.setLoopType("Heating")
        loop_sizing.setDesignLoopExitTemperature(60) #ML follows convention of sizing temp being larger than supplu temp
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
        setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, schedule)
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
        setpoint_manager_scheduled.addToNode(hot_water_plant.supplyOutletNode)
        # demand side components (water coils are added as they are added to airloops and zoneHVAC)
        hot_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
        pipe_demand_inlet.addToNode(hot_water_plant.demandInletNode)
        pipe_demand_outlet.addToNode(hot_water_plant.demandOutletNode)

        # pass back hot water plant
        result = hot_water_plant
        return result    
    
    end    
    
    def self.create_chilled_water_plant(model, runner, schedule, chiller_type)
    
        # chilled water plant
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
        if chiller_type == "WaterCooled"
          # create clgCapFuncTempCurve
          clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgCapFuncTempCurve.setCoefficient1Constant(1.07E+00)
          clgCapFuncTempCurve.setCoefficient2x(4.29E-02)
          clgCapFuncTempCurve.setCoefficient3xPOW2(4.17E-04)
          clgCapFuncTempCurve.setCoefficient4y(-8.10E-03)
          clgCapFuncTempCurve.setCoefficient5yPOW2(-4.02E-05)
          clgCapFuncTempCurve.setCoefficient6xTIMESY(-3.86E-04)
          clgCapFuncTempCurve.setMinimumValueofx(0)
          clgCapFuncTempCurve.setMaximumValueofx(20)
          clgCapFuncTempCurve.setMinimumValueofy(0)
          clgCapFuncTempCurve.setMaximumValueofy(50)
          # create eirFuncTempCurve
          eirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          eirFuncTempCurve.setCoefficient1Constant(4.68E-01)
          eirFuncTempCurve.setCoefficient2x(-1.38E-02)
          eirFuncTempCurve.setCoefficient3xPOW2(6.98E-04)
          eirFuncTempCurve.setCoefficient4y(1.09E-02)
          eirFuncTempCurve.setCoefficient5yPOW2(4.62E-04)
          eirFuncTempCurve.setCoefficient6xTIMESY(-6.82E-04)
          eirFuncTempCurve.setMinimumValueofx(0)
          eirFuncTempCurve.setMaximumValueofx(20)
          eirFuncTempCurve.setMinimumValueofy(0)
          eirFuncTempCurve.setMaximumValueofy(50)
          # create eirFuncPlrCurve
          eirFuncPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
          eirFuncPlrCurve.setCoefficient1Constant(1.41E-01)
          eirFuncPlrCurve.setCoefficient2x(6.55E-01)
          eirFuncPlrCurve.setCoefficient3xPOW2(2.03E-01)
          eirFuncPlrCurve.setMinimumValueofx(0)
          eirFuncPlrCurve.setMaximumValueofx(1.2)
          # construct chiller
          chiller = OpenStudio::Model::ChillerElectricEIR.new(model,clgCapFuncTempCurve,eirFuncTempCurve,eirFuncPlrCurve)
          chiller.setReferenceCOP(6.1)
          chiller.setCondenserType("WaterCooled")
          chiller.setChillerFlowMode("ConstantFlow")
        elsif chiller_type == "AirCooled"
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
        end
        # create a scheduled setpoint manager
        setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, schedule)
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
        setpoint_manager_scheduled.addToNode(chilled_water_plant.supplyOutletNode)
        # demand side components (water coils are added as they are added to airloops and ZoneHVAC)
        chilled_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
        pipe_demand_inlet.addToNode(chilled_water_plant.demandInletNode)
        pipe_demand_outlet.addToNode(chilled_water_plant.demandOutletNode)

        # pass back chilled water plant
        result = chilled_water_plant
        return result    
    
    end
    
    def self.create_radiant_chilled_water_plant(model, runner, schedule, chiller_type)
    
        # chilled water plant
        chilled_water_plant = OpenStudio::Model::PlantLoop.new(model)
        chilled_water_plant.setName("New Radiant Chilled Water Loop")
        chilled_water_plant.setMaximumLoopTemperature(98)
        chilled_water_plant.setMinimumLoopTemperature(1)
        loop_sizing = chilled_water_plant.sizingPlant
        loop_sizing.setLoopType("Cooling")
        loop_sizing.setDesignLoopExitTemperature(15)
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
        if chiller_type == "WaterCooled"
          # create clgCapFuncTempCurve
          clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          clgCapFuncTempCurve.setCoefficient1Constant(1.07E+00)
          clgCapFuncTempCurve.setCoefficient2x(4.29E-02)
          clgCapFuncTempCurve.setCoefficient3xPOW2(4.17E-04)
          clgCapFuncTempCurve.setCoefficient4y(-8.10E-03)
          clgCapFuncTempCurve.setCoefficient5yPOW2(-4.02E-05)
          clgCapFuncTempCurve.setCoefficient6xTIMESY(-3.86E-04)
          clgCapFuncTempCurve.setMinimumValueofx(0)
          clgCapFuncTempCurve.setMaximumValueofx(20)
          clgCapFuncTempCurve.setMinimumValueofy(0)
          clgCapFuncTempCurve.setMaximumValueofy(50)
          # create eirFuncTempCurve
          eirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
          eirFuncTempCurve.setCoefficient1Constant(4.68E-01)
          eirFuncTempCurve.setCoefficient2x(-1.38E-02)
          eirFuncTempCurve.setCoefficient3xPOW2(6.98E-04)
          eirFuncTempCurve.setCoefficient4y(1.09E-02)
          eirFuncTempCurve.setCoefficient5yPOW2(4.62E-04)
          eirFuncTempCurve.setCoefficient6xTIMESY(-6.82E-04)
          eirFuncTempCurve.setMinimumValueofx(0)
          eirFuncTempCurve.setMaximumValueofx(20)
          eirFuncTempCurve.setMinimumValueofy(0)
          eirFuncTempCurve.setMaximumValueofy(50)
          # create eirFuncPlrCurve
          eirFuncPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
          eirFuncPlrCurve.setCoefficient1Constant(1.41E-01)
          eirFuncPlrCurve.setCoefficient2x(6.55E-01)
          eirFuncPlrCurve.setCoefficient3xPOW2(2.03E-01)
          eirFuncPlrCurve.setMinimumValueofx(0)
          eirFuncPlrCurve.setMaximumValueofx(1.2)
          # construct chiller
          chiller = OpenStudio::Model::ChillerElectricEIR.new(model,clgCapFuncTempCurve,eirFuncTempCurve,eirFuncPlrCurve)
          chiller.setReferenceCOP(6.1)
          chiller.setCondenserType("WaterCooled")
          chiller.setChillerFlowMode("ConstantFlow")
        elsif chiller_type == "AirCooled"
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
        end
        # create a scheduled setpoint manager
        setpoint_manager_scheduled = OpenStudio::Model::SetpointManagerScheduled.new(model, schedule)
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
        setpoint_manager_scheduled.addToNode(chilled_water_plant.supplyOutletNode)
        # demand side components (water coils are added as they are added to airloops and ZoneHVAC)
        chilled_water_plant.addDemandBranchForComponent(pipe_demand_bypass)
        pipe_demand_inlet.addToNode(chilled_water_plant.demandInletNode)
        pipe_demand_outlet.addToNode(chilled_water_plant.demandOutletNode)

        # pass back chilled water plant
        result = chilled_water_plant
        return result    
    
    end
    
    def self.create_condenser_loop(model, runner, zone_hvac, hp_loop_schedule, hp_loop_cooling_schedule, hp_loop_heating_schedule)
    
        condenser_loop = nil
        heat_pump_loop = nil

        condLoopCoolingTemp_si = OpenStudio::convert(90,"F","C").get
        condLoopHeatingTemp_si = OpenStudio::convert(60,"F","C").get
        coolingTowerWB_si = OpenStudio::convert(68,"F","C").get
        boilerHWST_si =  OpenStudio::convert(120,"F","C").get
        coolingTowerDeltaT = 10.0
        boilerEff = 0.9
        boilerFuelType = "NaturalGas"
        coolingTowerApproach = 7.0

        # check for water-cooled chillers
        waterCooledChiller = false
        model.getChillerElectricEIRs.each do |chiller|
          next if waterCooledChiller == true
          if chiller.condenserType == "WaterCooled"
            waterCooledChiller = true
          end   
        end
        # create condenser loop for water-cooled chillers
        if waterCooledChiller
          # create condenser loop for water-cooled chiller(s)
          condenser_loop = OpenStudio::Model::PlantLoop.new(model)
          condenser_loop.setName("New Condenser Loop")
          condenser_loop.setMaximumLoopTemperature(80)
          condenser_loop.setMinimumLoopTemperature(5)
          loop_sizing = condenser_loop.sizingPlant
          loop_sizing.setLoopType("Condenser")
          loop_sizing.setDesignLoopExitTemperature(29.4)
          loop_sizing.setLoopDesignTemperatureDifference(5.6)
          # create a pump
          pump = OpenStudio::Model::PumpVariableSpeed.new(model)
          pump.setRatedPumpHead(134508) #Pa
          pump.setMotorEfficiency(0.9)
          pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
          pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
          pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
          pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
          # create a cooling tower
          tower = OpenStudio::Model::CoolingTowerVariableSpeed.new(model)
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
          # create a setpoint manager
          setpoint_manager_follow_oa = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
          setpoint_manager_follow_oa.setOffsetTemperatureDifference(0)
          setpoint_manager_follow_oa.setMaximumSetpointTemperature(80)
          setpoint_manager_follow_oa.setMinimumSetpointTemperature(5)
          # connect components to plant loop
          # supply side components
          condenser_loop.addSupplyBranchForComponent(tower)
          condenser_loop.addSupplyBranchForComponent(pipe_supply_bypass)
          pump.addToNode(condenser_loop.supplyInletNode)
          pipe_supply_outlet.addToNode(condenser_loop.supplyOutletNode)
          setpoint_manager_follow_oa.addToNode(condenser_loop.supplyOutletNode)
          # demand side components
          model.getChillerElectricEIRs.each do |chiller|
            if chiller.condenserType == "WaterCooled" # works only if chillers not already connected to condenser loop(s)
              condenser_loop.addDemandBranchForComponent(chiller)
            end   
          end
          condenser_loop.addDemandBranchForComponent(pipe_demand_bypass)
          pipe_demand_inlet.addToNode(condenser_loop.demandInletNode)
          pipe_demand_outlet.addToNode(condenser_loop.demandOutletNode)
        end
        if zone_hvac == "GSHP" or zone_hvac == "WSHP"
          # create condenser loop for heat pumps
          condenser_loop = OpenStudio::Model::PlantLoop.new(model)
          condenser_loop.setName("Heat Pump Loop")
          condenser_loop.setMaximumLoopTemperature(80)
          condenser_loop.setMinimumLoopTemperature(5)
          loop_sizing = condenser_loop.sizingPlant
          loop_sizing.setLoopType("Condenser")
          if zone_hvac == "GSHP"
            loop_sizing.setDesignLoopExitTemperature(condLoopCoolingTemp_si)
            loop_sizing.setLoopDesignTemperatureDifference(coolingTowerDeltaT/1.8)
          elsif zone_hvac == "WSHP" 
            loop_sizing.setDesignLoopExitTemperature(condLoopCoolingTemp_si)
            loop_sizing.setLoopDesignTemperatureDifference(coolingTowerDeltaT/1.8)
          end  
          # create a pump
          pump = OpenStudio::Model::PumpVariableSpeed.new(model)
          pump.setRatedPumpHead(134508) #Pa
          pump.setMotorEfficiency(0.9)
          pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
          pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
          pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
          pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
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
          # create setpoint managers
          setpoint_manager_scheduled_loop = OpenStudio::Model::SetpointManagerScheduled.new(model, hp_loop_schedule)
          setpoint_manager_scheduled_cooling = OpenStudio::Model::SetpointManagerScheduled.new(model, hp_loop_cooling_schedule)
          setpoint_manager_scheduled_heating = OpenStudio::Model::SetpointManagerScheduled.new(model, hp_loop_heating_schedule)
          # connect components to plant loop
          # supply side components
          condenser_loop.addSupplyBranchForComponent(pipe_supply_bypass)
          pump.addToNode(condenser_loop.supplyInletNode)
          pipe_supply_outlet.addToNode(condenser_loop.supplyOutletNode)
          setpoint_manager_scheduled_loop.addToNode(condenser_loop.supplyOutletNode)
          # demand side components
          condenser_loop.addDemandBranchForComponent(pipe_demand_bypass)
          pipe_demand_inlet.addToNode(condenser_loop.demandInletNode)
          pipe_demand_outlet.addToNode(condenser_loop.demandOutletNode)
          # add additional components according to specific system type
          if zone_hvac == "GSHP"
            # add district cooling and heating to supply side
            district_cooling = OpenStudio::Model::DistrictCooling.new(model)
            district_cooling.setNominalCapacity(1000000000000) # large number; no autosizing
            condenser_loop.addSupplyBranchForComponent(district_cooling)
            setpoint_manager_scheduled_cooling.addToNode(district_cooling.outletModelObject.get.to_Node.get)
            district_heating = OpenStudio::Model::DistrictHeating.new(model)
            district_heating.setNominalCapacity(1000000000000) # large number; no autosizing
            district_heating.addToNode(district_cooling.outletModelObject.get.to_Node.get)
            setpoint_manager_scheduled_heating.addToNode(district_heating.outletModelObject.get.to_Node.get)
            # add heat pumps to demand side after they get created
          elsif zone_hvac == "WSHP"
            # add a boiler and cooling tower to supply side
            # create a boiler
            boiler = OpenStudio::Model::BoilerHotWater.new(model)
            boiler.setNominalThermalEfficiency(boilerEff)
            boiler.setFuelType(boilerFuelType)
            boiler.setDesignWaterOutletTemperature(boilerHWST_si)
            condenser_loop.addSupplyBranchForComponent(boiler)
            setpoint_manager_scheduled_heating.addToNode(boiler.outletModelObject.get.to_Node.get)
            # create a cooling tower
            tower = OpenStudio::Model::CoolingTowerVariableSpeed.new(model)
            tower.setDesignInletAirWetBulbTemperature(coolingTowerWB_si)
            tower.setDesignApproachTemperature(coolingTowerApproach/1.8)
            tower.setDesignRangeTemperature(coolingTowerApproach/1.8)
            tower.addToNode(boiler.outletModelObject.get.to_Node.get)
            setpoint_manager_scheduled_cooling.addToNode(tower.outletModelObject.get.to_Node.get)
          end
          heat_pump_loop = condenser_loop    
        end
          
        # pass back condenser loop(s)
        result = condenser_loop, heat_pump_loop
        return result
    
    end
    
    def self.create_primary_air_loop(model, runner, hot_water_plant, chilled_water_plant, primary_sat_schedule)
    
        primary_airloops = []
        assignedThermalZones = []
        model.getThermalZones.sort.each do |thermal_zone|
          #ML stories need to be reordered from the ground up
          thermalZonesToAdd = []
          # make sure spaces are assigned to thermal zones
          # otherwise might want to send a warning
          # make sure zone was not already assigned to another air loop
          unless assignedThermalZones.include? thermal_zone
            # make sure thermal zones are not duplicated (spaces can share thermal zones)
            unless thermalZonesToAdd.include? thermal_zone
              thermalZonesToAdd << thermal_zone
            end
          end                
          
          # make sure thermal zones don't get added to more than one air loop
          assignedThermalZones << thermalZonesToAdd
                
          # create new air loop if story contains primary zones
          unless thermalZonesToAdd.empty?
            airloop_primary = OpenStudio::Model::AirLoopHVAC.new(model)
            airloop_primary.setName("#{thermal_zone.name} Air Loop")
            # modify system sizing properties
            sizing_system = airloop_primary.sizingSystem
            # set central heating and cooling temperatures for sizing
            sizing_system.setCentralCoolingDesignSupplyAirTemperature(12.8)
            sizing_system.setCentralHeatingDesignSupplyAirTemperature(40) #ML OS default is 16.7
            # load specification
            sizing_system.setSystemOutdoorAirMethod("ZoneSum") #ML OS default is ZoneSum
            sizing_system.setTypeofLoadtoSizeOn("Sensible") #VAV
            sizing_system.setAllOutdoorAirinCooling(false) #VAV
            sizing_system.setAllOutdoorAirinHeating(false) #VAV
            air_loop_comps = []
            # set availability schedule
            airloop_primary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule())
            # create air loop fan
            # create variable speed fan and set system sizing accordingly
            sizing_system.setMinimumSystemAirFlowRatio(0.3) #DCV
            # variable speed fan
            fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule())
            fan.setFanEfficiency(0.69)
            fan.setPressureRise(1125) #Pa
            fan.autosizeMaximumFlowRate()
            fan.setFanPowerMinimumFlowFraction(0.6)
            fan.setMotorEfficiency(0.9)
            fan.setMotorInAirstreamFraction(1.0)
            air_loop_comps << fan
            # create heating coil
            # water coil
            heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule())
            air_loop_comps << heating_coil 
            # create cooling coil
            # water coil
            cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule())
            air_loop_comps << cooling_coil
            # create controller outdoor air
            controller_OA = OpenStudio::Model::ControllerOutdoorAir.new(model)
            controller_OA.autosizeMinimumOutdoorAirFlowRate()
            controller_OA.autosizeMaximumOutdoorAirFlowRate()
            # create ventilation schedules and assign to OA controller
            # multizone VAV that ventilates
            # controller_OA.setMaximumFractionofOutdoorAirSchedule(options["ventilation_schedule"])
            controller_OA.setEconomizerControlType("DifferentialEnthalpy")
            # add night cycling (ML would people actually do this for a VAV system?))
            airloop_primary.setNightCycleControlType("CycleOnAny") #ML Does this work with variable speed fans?
            controller_OA.setHeatRecoveryBypassControlType("BypassWhenOAFlowGreaterThanMinimum")
            # create outdoor air system
            system_OA = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, controller_OA)
            air_loop_comps << system_OA
            # create scheduled setpoint manager for airloop
            # VAV for cooling and ventilation
            setpoint_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, primary_sat_schedule)
            # connect components to airloop
            # find the supply inlet node of the airloop
            airloop_supply_inlet = airloop_primary.supplyInletNode
            # add the components to the airloop
            air_loop_comps.each do |comp|
              comp.addToNode(airloop_supply_inlet)
              if comp.to_CoilHeatingWater.is_initialized
                hot_water_plant.addDemandBranchForComponent(comp)
                comp.controllerWaterCoil.get.setMinimumActuatedFlow(0)
              elsif comp.to_CoilCoolingWater.is_initialized
                chilled_water_plant.addDemandBranchForComponent(comp)
                comp.controllerWaterCoil.get.setMinimumActuatedFlow(0)
              end
            end        
            # add setpoint manager to supply equipment outlet node
            setpoint_manager.addToNode(airloop_primary.supplyOutletNode)
            # add thermal zones to airloop
            thermalZonesToAdd.each do |zone|
              # make an air terminal for the zone
              air_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule())
              # attach new terminal to the zone and to the airloop
              airloop_primary.addBranchForZone(zone, air_terminal.to_StraightComponent)
            end 
            primary_airloops << airloop_primary       
          end
        end

        # pass back primary airloops
        result = primary_airloops
        return result
    
    end
    
    def self.create_primary_zone_equipment(model, runner, hot_water_plant, radiant_hot_water_plant, chilled_water_plant, radiant_chilled_water_plant, heat_pump_loop, mean_radiant_heating_schedule, mean_radiant_cooling_schedule, zone_hvac)
    
        wshpFanType = "PSC"
        wshpCoolingEER = 14
        wshpHeatingCOP = 4.0
    
        model.getThermalZones.each do |zone|
            if zone_hvac == "FanCoil"
              # create fan coil
              # create fan
              fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule())
              fan.setFanEfficiency(0.5)
              fan.setPressureRise(75) #Pa
              fan.autosizeMaximumFlowRate()
              fan.setMotorEfficiency(0.9)
              fan.setMotorInAirstreamFraction(1.0)
              # create cooling coil and connect to chilled water plant
              cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule())
              chilled_water_plant.addDemandBranchForComponent(cooling_coil)
              cooling_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
              # create heating coil and connect to hot water plant
              heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule())
              hot_water_plant.addDemandBranchForComponent(heating_coil)
              heating_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
              # construct fan coil
              fan_coil = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model, model.alwaysOnDiscreteSchedule(), fan, cooling_coil, heating_coil)
              fan_coil.setMaximumOutdoorAirFlowRate(0)                                                          
              # add fan coil to thermal zone
              fan_coil.addToThermalZone(zone)
            elsif zone_hvac == "WSHP" or zone_hvac == "GSHP"
              # create water source heat pump and attach to heat pump loop
              # create fan
              fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule())
              fan.setFanEfficiency(0.75) 
              fan_eff = fan.fanEfficiency()
              fan.setMotorEfficiency(0.9)
              motor_eff = fan.motorEfficiency()
              fan.autosizeMaximumFlowRate()
              if wshpFanType == "PSC" # use 0.3W/cfm, ECM - 0.2W/cfm
                watt_per_cfm = 0.30 # W/cfm
              else
                watt_per_cfm = 0.20 # W/cfm
              end
              pres_rise = OpenStudio::convert(watt_per_cfm * fan_eff * motor_eff/0.1175,"inH_{2}O","Pa").get  
              fan.setPressureRise(pres_rise) #Pa
              fan.setMotorInAirstreamFraction(1.0)
              # create cooling coil and connect to heat pump loop
              cooling_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model)
              cooling_coil.setRatedCoolingCoefficientofPerformance(wshpCoolingEER/3.412) # xf 061014: need to change per fan power and pump power adjustment
              cooling_coil.setRatedCoolingCoefficientofPerformance(6.45)
              cooling_coil.setTotalCoolingCapacityCoefficient1(-9.149069561)
              cooling_coil.setTotalCoolingCapacityCoefficient2(10.87814026)
              cooling_coil.setTotalCoolingCapacityCoefficient3(-1.718780157)
              cooling_coil.setTotalCoolingCapacityCoefficient4(0.746414818)
              cooling_coil.setTotalCoolingCapacityCoefficient5(0.0)
              cooling_coil.setSensibleCoolingCapacityCoefficient1(-5.462690012)
              cooling_coil.setSensibleCoolingCapacityCoefficient2(17.95968138)
              cooling_coil.setSensibleCoolingCapacityCoefficient3(-11.87818402)
              cooling_coil.setSensibleCoolingCapacityCoefficient4(-0.980163419)
              cooling_coil.setSensibleCoolingCapacityCoefficient5(0.767285761)
              cooling_coil.setSensibleCoolingCapacityCoefficient6(0.0)
              cooling_coil.setCoolingPowerConsumptionCoefficient1(-3.205409884)
              cooling_coil.setCoolingPowerConsumptionCoefficient2(-0.976409399)
              cooling_coil.setCoolingPowerConsumptionCoefficient3(3.97892546)
              cooling_coil.setCoolingPowerConsumptionCoefficient4(0.938181818)
              cooling_coil.setCoolingPowerConsumptionCoefficient5(0.0)
              heat_pump_loop.addDemandBranchForComponent(cooling_coil)
              # create heating coil and connect to heat pump loop
              heating_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model)
              heating_coil.setRatedHeatingCoefficientofPerformance(wshpHeatingCOP) # xf 061014: need to change per fan power and pump power adjustment
              heating_coil.setRatedHeatingCoefficientofPerformance(4.0)
              heating_coil.setHeatingCapacityCoefficient1(-1.361311959)
              heating_coil.setHeatingCapacityCoefficient2(-2.471798046)
              heating_coil.setHeatingCapacityCoefficient3(4.173164514)
              heating_coil.setHeatingCapacityCoefficient4(0.640757401)
              heating_coil.setHeatingCapacityCoefficient5(0.0)
              heating_coil.setHeatingPowerConsumptionCoefficient1(-2.176941116)
              heating_coil.setHeatingPowerConsumptionCoefficient2(0.832114286)
              heating_coil.setHeatingPowerConsumptionCoefficient3(1.570743399)
              heating_coil.setHeatingPowerConsumptionCoefficient4(0.690793651)
              heating_coil.setHeatingPowerConsumptionCoefficient5(0.0)
              heat_pump_loop.addDemandBranchForComponent(heating_coil)
              # create supplemental heating coil
              supplemental_heating_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule())
              # construct heat pump
              heat_pump = OpenStudio::Model::ZoneHVACWaterToAirHeatPump.new(model, model.alwaysOnDiscreteSchedule(), fan, heating_coil, cooling_coil, supplemental_heating_coil)																		
              heat_pump.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(OpenStudio::OptionalDouble.new(0))
              heat_pump.setOutdoorAirFlowRateDuringCoolingOperation(OpenStudio::OptionalDouble.new(0))
              heat_pump.setOutdoorAirFlowRateDuringHeatingOperation(OpenStudio::OptionalDouble.new(0))
              heat_pump.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(OpenStudio::OptionalDouble.new(0))
              # add heat pump to thermal zone
              heat_pump.addToThermalZone(zone)
            elsif zone_hvac == "ASHP"
              # create air source heat pump
              # create fan
              fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule())
              fan.setFanEfficiency(0.5)
              fan.setPressureRise(75) #Pa
              fan.autosizeMaximumFlowRate()
              fan.setMotorEfficiency(0.9)
              fan.setMotorInAirstreamFraction(1.0)
              # create heating coil
              # create htgCapFuncTempCurve
              htgCapFuncTempCurve = OpenStudio::Model::CurveCubic.new(model)
              htgCapFuncTempCurve.setCoefficient1Constant(0.758746)
              htgCapFuncTempCurve.setCoefficient2x(0.027626)
              htgCapFuncTempCurve.setCoefficient3xPOW2(0.000148716)
              htgCapFuncTempCurve.setCoefficient4xPOW3(0.0000034992)
              htgCapFuncTempCurve.setMinimumValueofx(-20)
              htgCapFuncTempCurve.setMaximumValueofx(20)
              # create htgCapFuncFlowFracCurve
              htgCapFuncFlowFracCurve = OpenStudio::Model::CurveCubic.new(model)
              htgCapFuncFlowFracCurve.setCoefficient1Constant(0.84)
              htgCapFuncFlowFracCurve.setCoefficient2x(0.16)
              htgCapFuncFlowFracCurve.setCoefficient3xPOW2(0)
              htgCapFuncFlowFracCurve.setCoefficient4xPOW3(0)
              htgCapFuncFlowFracCurve.setMinimumValueofx(0.5)
              htgCapFuncFlowFracCurve.setMaximumValueofx(1.5)
              # create htgEirFuncTempCurve
              htgEirFuncTempCurve = OpenStudio::Model::CurveCubic.new(model)
              htgEirFuncTempCurve.setCoefficient1Constant(1.19248)
              htgEirFuncTempCurve.setCoefficient2x(-0.0300438)
              htgEirFuncTempCurve.setCoefficient3xPOW2(0.00103745)
              htgEirFuncTempCurve.setCoefficient4xPOW3(-0.000023328)
              htgEirFuncTempCurve.setMinimumValueofx(-20)
              htgEirFuncTempCurve.setMaximumValueofx(20)
              # create htgEirFuncFlowFracCurve
              htgEirFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
              htgEirFuncFlowFracCurve.setCoefficient1Constant(1.3824)
              htgEirFuncFlowFracCurve.setCoefficient2x(-0.4336)
              htgEirFuncFlowFracCurve.setCoefficient3xPOW2(0.0512)
              htgEirFuncFlowFracCurve.setMinimumValueofx(0)
              htgEirFuncFlowFracCurve.setMaximumValueofx(1)
              # create htgPlrCurve
              htgPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
              htgPlrCurve.setCoefficient1Constant(0.75)
              htgPlrCurve.setCoefficient2x(0.25)
              htgPlrCurve.setCoefficient3xPOW2(0.0)
              htgPlrCurve.setMinimumValueofx(0.0)
              htgPlrCurve.setMaximumValueofx(1.0)
              # heating coil
              heating_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule(), htgCapFuncTempCurve, htgCapFuncFlowFracCurve, htgEirFuncTempCurve, htgEirFuncFlowFracCurve, htgPlrCurve)
              heating_coil.setRatedCOP(3.4)
              heating_coil.setCrankcaseHeaterCapacity(200)
              heating_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(8)
              heating_coil.autosizeResistiveDefrostHeaterCapacity
              # create cooling coil
              # create clgCapFuncTempCurve
              clgCapFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
              clgCapFuncTempCurve.setCoefficient1Constant(0.942587793)
              clgCapFuncTempCurve.setCoefficient2x(0.009543347)
              clgCapFuncTempCurve.setCoefficient3xPOW2(0.0018423)
              clgCapFuncTempCurve.setCoefficient4y(-0.011042676)
              clgCapFuncTempCurve.setCoefficient5yPOW2(0.000005249)
              clgCapFuncTempCurve.setCoefficient6xTIMESY(-0.000009720)
              clgCapFuncTempCurve.setMinimumValueofx(17)
              clgCapFuncTempCurve.setMaximumValueofx(22)
              clgCapFuncTempCurve.setMinimumValueofy(13)
              clgCapFuncTempCurve.setMaximumValueofy(46)
              # create clgCapFuncFlowFracCurve
              clgCapFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
              clgCapFuncFlowFracCurve.setCoefficient1Constant(0.718954)
              clgCapFuncFlowFracCurve.setCoefficient2x(0.435436)
              clgCapFuncFlowFracCurve.setCoefficient3xPOW2(-0.154193)
              clgCapFuncFlowFracCurve.setMinimumValueofx(0.75)
              clgCapFuncFlowFracCurve.setMaximumValueofx(1.25)
              # create clgEirFuncTempCurve
              clgEirFuncTempCurve = OpenStudio::Model::CurveBiquadratic.new(model)
              clgEirFuncTempCurve.setCoefficient1Constant(0.342414409)
              clgEirFuncTempCurve.setCoefficient2x(0.034885008)
              clgEirFuncTempCurve.setCoefficient3xPOW2(-0.000623700)
              clgEirFuncTempCurve.setCoefficient4y(0.004977216)
              clgEirFuncTempCurve.setCoefficient5yPOW2(0.000437951)
              clgEirFuncTempCurve.setCoefficient6xTIMESY(-0.000728028)
              clgEirFuncTempCurve.setMinimumValueofx(17)
              clgEirFuncTempCurve.setMaximumValueofx(22)
              clgEirFuncTempCurve.setMinimumValueofy(13)
              clgEirFuncTempCurve.setMaximumValueofy(46)
              # create clgEirFuncFlowFracCurve
              clgEirFuncFlowFracCurve = OpenStudio::Model::CurveQuadratic.new(model)
              clgEirFuncFlowFracCurve.setCoefficient1Constant(1.1552)
              clgEirFuncFlowFracCurve.setCoefficient2x(-0.1808)
              clgEirFuncFlowFracCurve.setCoefficient3xPOW2(0.0256)
              clgEirFuncFlowFracCurve.setMinimumValueofx(0.5)
              clgEirFuncFlowFracCurve.setMaximumValueofx(1.5)
              # create clgPlrCurve
              clgPlrCurve = OpenStudio::Model::CurveQuadratic.new(model)
              clgPlrCurve.setCoefficient1Constant(0.75)
              clgPlrCurve.setCoefficient2x(0.25)
              clgPlrCurve.setCoefficient3xPOW2(0.0)
              clgPlrCurve.setMinimumValueofx(0.0)
              clgPlrCurve.setMaximumValueofx(1.0)
              # cooling coil
              cooling_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model, model.alwaysOnDiscreteSchedule(), clgCapFuncTempCurve, clgCapFuncFlowFracCurve, clgEirFuncTempCurve, clgEirFuncFlowFracCurve, clgPlrCurve)
              cooling_coil.setRatedCOP(OpenStudio::OptionalDouble.new(4))
              # create supplemental heating coil
              supplemental_heating_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule())
              # construct heat pump
              heat_pump = OpenStudio::Model::ZoneHVACPackagedTerminalHeatPump.new(model, model.alwaysOnDiscreteSchedule(), fan, heating_coil, cooling_coil, supplemental_heating_coil)
              heat_pump.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(0)
              heat_pump.setOutdoorAirFlowRateDuringCoolingOperation(0)
              heat_pump.setOutdoorAirFlowRateDuringHeatingOperation(0)
              heat_pump.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(0)
              # add heat pump to thermal zone
              heat_pump.addToThermalZone(zone)
            elsif zone_hvac == "Baseboard"
              # create baseboard heater add add to thermal zone and hot water loop
              baseboard_coil = OpenStudio::Model::CoilHeatingWaterBaseboard.new(model)
              baseboard_heater = OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.new(model, model.alwaysOnDiscreteSchedule(), baseboard_coil)
              baseboard_heater.addToThermalZone(zone)          
              hot_water_plant.addDemandBranchForComponent(baseboard_coil)
            elsif zone_hvac == "Radiant"
              # create low temperature radiant object and add to thermal zone and radiant plant loops
              # create hot water coil and attach to radiant hot water loop
              heating_coil = OpenStudio::Model::CoilHeatingLowTempRadiantVarFlow.new(model, mean_radiant_heating_schedule)
              radiant_hot_water_plant.addDemandBranchForComponent(heating_coil)
              # create chilled water coil and attach to radiant chilled water loop
              cooling_coil = OpenStudio::Model::CoilCoolingLowTempRadiantVarFlow.new(model, mean_radiant_cooling_schedule)
              radiant_chilled_water_plant.addDemandBranchForComponent(cooling_coil)
              low_temp_radiant = OpenStudio::Model::ZoneHVACLowTempRadiantVarFlow.new(model, model.alwaysOnDiscreteSchedule(), heating_coil, cooling_coil)
              low_temp_radiant.setRadiantSurfaceType("Floors")
              low_temp_radiant.setHydronicTubingInsideDiameter(0.012)
              low_temp_radiant.setTemperatureControlType("MeanRadiantTemperature")
              low_temp_radiant.addToThermalZone(zone)
              # create radiant floor construction and substitute for existing floor (interior or exterior) constructions
              # create materials for radiant floor construction
              layers = []
              # ignore layer below insulation, which will depend on boundary condition
              layers << rigid_insulation_1in = OpenStudio::Model::StandardOpaqueMaterial.new(model,"Rough",0.0254,0.02,56.06,1210)
              layers << concrete_2in = OpenStudio::Model::StandardOpaqueMaterial.new(model,"MediumRough",0.0508,2.31,2322,832)
              layers << concrete_2in
              # create radiant floor construction from materials
              radiant_floor = OpenStudio::Model::ConstructionWithInternalSource.new(layers)
              radiant_floor.setSourcePresentAfterLayerNumber(2)
              radiant_floor.setSourcePresentAfterLayerNumber(2)
              # assign radiant construction to zone floor
              zone.spaces.each do |space|
                space.surfaces.each do |surface|
                  if surface.surfaceType == "Floor"
                    surface.setConstruction(radiant_floor)
                  end
                end
              end
            elsif zone_hvac == "DualDuct"
              # create baseboard heater add add to thermal zone and hot water loop
              baseboard_coil = OpenStudio::Model::CoilHeatingWaterBaseboard.new(model)
              baseboard_heater = OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.new(model, model.alwaysOnDiscreteSchedule(), baseboard_coil)
              baseboard_heater.addToThermalZone(zone)          
              hot_water_plant.addDemandBranchForComponent(baseboard_coil)
              # create fan coil (to mimic functionality of DOAS)
              # variable speed fan
              fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule())
              fan.setFanEfficiency(0.69)
              fan.setPressureRise(75) #Pa #ML This number is a guess; zone equipment pretending to be a DOAS
              fan.autosizeMaximumFlowRate()
              fan.setFanPowerMinimumFlowFraction(0.6)
              fan.setMotorEfficiency(0.9)
              fan.setMotorInAirstreamFraction(1.0)
              # create chilled water coil and attach to chilled water loop
              cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule())
              chilled_water_plant.addDemandBranchForComponent(cooling_coil)
              cooling_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
              # create hot water coil and attach to hot water loop
              heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule())
              hot_water_plant.addDemandBranchForComponent(heating_coil)
              heating_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
              # construct fan coil (DOAS) and attach to thermal zone
              fan_coil_doas = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model, model.alwaysOnDiscreteSchedule(), fan, cooling_coil, heating_coil)
              fan_coil_doas.setCapacityControlMethod("VariableFanVariableFlow")
              fan_coil_doas.addToThermalZone(zone)
            end
        end    
    
    end

end