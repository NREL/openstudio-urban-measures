class HelperMethods

    def self.add_watertoairhp(model, heat_pump_loop, thermal_zones)

        water_to_air_hp_systems = []
        thermal_zones.each do |zone|
        
            supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        
            htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model)
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

            heat_pump_loop.addDemandBranchForComponent(htg_coil)        

            clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model)
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
        
            heat_pump_loop.addDemandBranchForComponent(clg_coil)    
        
            # add fan
            fan = OpenStudio::Model::FanOnOff.new(model,model.alwaysOnDiscreteSchedule)
            fan.setName("#{zone.name} Water-to_Air HP Fan")
            fan_static_pressure_in_h2o = 1.33
            fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, "inH_{2}O","Pa").get
            fan.setPressureRise(fan_static_pressure_pa)
            fan.setFanEfficiency(0.52)
            fan.setMotorEfficiency(0.8)  
        
            water_to_air_hp_system = OpenStudio::Model::ZoneHVACWaterToAirHeatPump.new(model, 
                                                                                       model.alwaysOnDiscreteSchedule, 
                                                                                       fan, 
                                                                                       htg_coil, 
                                                                                       clg_coil,
                                                                                       supplemental_htg_coil)
                                                                                    
            water_to_air_hp_system.addToThermalZone(zone)

            water_to_air_hp_systems << water_to_air_hp_system
          
        end

        return water_to_air_hp_systems                                                                                
        
    end

    def self.zones_with_thermostats(thermal_zones)
        
        zones_with_thermostats = []
        thermal_zones.each do |thermal_zone|
            if thermal_zone.thermostat.is_initialized
                zones_with_thermostats << thermal_zone
            end
        end
        
        return zones_with_thermostats
        
    end

    def self.make_district_hot_water_loop(model, runner, loop)

        loop.supplyComponents.each do |supplyComponent|
            if supplyComponent.to_BoilerHotWater.is_initialized
                boiler = supplyComponent.to_BoilerHotWater.get
                runner.registerInfo("Removing '#{boiler.name}' from '#{loop.name}'.")
                loop.removeSupplyBranchWithComponent(boiler)
            end
        end
        district_heating = OpenStudio::Model::DistrictHeating.new(model)
        district_heating.setNominalCapacity(1000000000000) # large number; no autosizing
        loop.addSupplyBranchForComponent(district_heating)
        runner.registerInfo("Adding '#{district_heating.name}' to '#{loop.name}'.")
        
        return loop
        
    end

    def self.make_district_chilled_water_loop(model, runner, loop)

        loop.supplyComponents.each do |supplyComponent|
            if supplyComponent.to_ChillerElectricEIR.is_initialized
                chiller = supplyComponent.to_ChillerElectricEIR.get
                runner.registerInfo("Removing '#{chiller.name}' from '#{loop.name}'.")
                loop.removeSupplyBranchWithComponent(chiller)
            end
        end
        district_cooling = OpenStudio::Model::DistrictCooling.new(model)
        district_cooling.setNominalCapacity(1000000000000) # large number; no autosizing
        loop.addSupplyBranchForComponent(district_cooling)
        runner.registerInfo("Adding '#{district_cooling.name}' to '#{loop.name}'.")
        
        return loop

    end

    def self.make_district_heat_pump_loop(model, runner, loop)

        hp_stpt_manager = nil
        loop.supplyComponents.each do |supplyComponent|
            if supplyComponent.to_BoilerHotWater.is_initialized
                boiler = supplyComponent.to_BoilerHotWater.get
                node = boiler.outletModelObject.get.to_Node.get
                node.setpointManagers.each do |setpointManager|
                    if setpointManager.to_SetpointManagerScheduledDualSetpoint.is_initialized
                        hp_stpt_manager = setpointManager.to_SetpointManagerScheduledDualSetpoint.get
                    end
                end
                runner.registerInfo("Removing '#{boiler.name}' from '#{loop.name}'.")
                loop.removeSupplyBranchWithComponent(boiler)
            elsif supplyComponent.to_EvaporativeFluidCoolerSingleSpeed.is_initialized
                fluid_cooler = supplyComponent.to_EvaporativeFluidCoolerSingleSpeed.get
                runner.registerInfo("Removing '#{fluid_cooler.name}' from '#{loop.name}'.")
                loop.removeSupplyBranchWithComponent(fluid_cooler)        
            end
        end
        district_heating = OpenStudio::Model::DistrictHeating.new(model)
        district_heating.setNominalCapacity(1000000000000) # large number; no autosizing
        loop.addSupplyBranchForComponent(district_heating)
        puts district_heating.outletModelObject.get.to_Node.get
        # TODO: the following doesn't work for some reason
        # hp_stpt_manager.addToNode(district_heating.outletModelObject.get.to_Node.get)
        runner.registerInfo("Adding '#{district_heating.name}' to '#{loop.name}'.")
        district_cooling = OpenStudio::Model::DistrictCooling.new(model)
        district_cooling.setNominalCapacity(1000000000000) # large number; no autosizing
        loop.addSupplyBranchForComponent(district_cooling)    
        runner.registerInfo("Adding '#{district_cooling.name}' to '#{loop.name}'.")

        return loop
        
    end

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

    def self.add_pthp(model,
                      thermal_zones,
                      fan_type,
                      heating_type,
                      cooling_type,
                      chilled_water_loop=nil)

        thermal_zones.each do |zone|
          OpenStudio::logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PTHP for #{zone.name}.")
        end  

        # schedule: always off
        always_off = OpenStudio::Model::ScheduleRuleset.new(model)
        always_off.setName("ALWAYS_OFF")
        always_off.defaultDaySchedule.setName("ALWAYS_OFF day")
        always_off.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 0.0)
        always_off.setSummerDesignDaySchedule(always_off.defaultDaySchedule)
        always_off.setWinterDesignDaySchedule(always_off.defaultDaySchedule)

        # Make a PTAC for each zone
        pthps = []
        thermal_zones.each do |zone|

          # Zone sizing
          sizing_zone = zone.sizingZone
          sizing_zone.setZoneCoolingDesignSupplyAirTemperature(14)
          sizing_zone.setZoneHeatingDesignSupplyAirTemperature(50.0)
          sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)
          sizing_zone.setZoneHeatingDesignSupplyAirHumidityRatio(0.008)

          # add fan
          fan = nil
          if fan_type == "ConstantVolume"
            fan = OpenStudio::Model::FanConstantVolume.new(model,model.alwaysOnDiscreteSchedule)
            fan.setName("#{zone.name} PTAC Fan")
            fan_static_pressure_in_h2o = 1.33
            fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, "inH_{2}O","Pa").get
            fan.setPressureRise(fan_static_pressure_pa)
            fan.setFanEfficiency(0.52)
            fan.setMotorEfficiency(0.8)
          elsif fan_type == "Cycling"
            fan = OpenStudio::Model::FanOnOff.new(model,model.alwaysOnDiscreteSchedule)
            fan.setName("#{zone.name} PTAC Fan")
            fan_static_pressure_in_h2o = 1.33
            fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, "inH_{2}O","Pa").get
            fan.setPressureRise(fan_static_pressure_pa)
            fan.setFanEfficiency(0.52)
            fan.setMotorEfficiency(0.8)
          else
            OpenStudio::logFree(OpenStudio::Warn, 'openstudio.model.Model', "pthp_fan_type of #{fan_type} is not recognized.")
          end

          supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
          
          htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
          htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
          htg_cap_f_of_temp.setCoefficient2x(0.027626)
          htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
          htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
          htg_cap_f_of_temp.setMinimumValueofx(-20.0)
          htg_cap_f_of_temp.setMaximumValueofx(20.0)

          htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(model)
          htg_cap_f_of_flow.setCoefficient1Constant(0.84)
          htg_cap_f_of_flow.setCoefficient2x(0.16)
          htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
          htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
          htg_cap_f_of_flow.setMinimumValueofx(0.5)
          htg_cap_f_of_flow.setMaximumValueofx(1.5)

          htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
          htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
          htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
          htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
          htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
          htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
          htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

          htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
          htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
          htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
          htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
          htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
          htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

          htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
          htg_part_load_fraction.setCoefficient1Constant(0.75)
          htg_part_load_fraction.setCoefficient2x(0.25)
          htg_part_load_fraction.setCoefficient3xPOW2(0.0)
          htg_part_load_fraction.setMinimumValueofx(0.0)
          htg_part_load_fraction.setMaximumValueofx(1.0)

          htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model,
                                                                     model.alwaysOnDiscreteSchedule,
                                                                     htg_cap_f_of_temp,
                                                                     htg_cap_f_of_flow,
                                                                     htg_energy_input_ratio_f_of_temp,
                                                                     htg_energy_input_ratio_f_of_flow,
                                                                     htg_part_load_fraction)
                                                                     
          htg_coil.setName("#{zone.name} PTHP 1spd DX Htg Coil")

          # add cooling coil
          clg_coil = nil
          if cooling_type == "Two Speed DX AC"

            clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
            clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
            clg_cap_f_of_temp.setCoefficient2x(0.04426)
            clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
            clg_cap_f_of_temp.setCoefficient4y(0.00333)
            clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
            clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
            clg_cap_f_of_temp.setMinimumValueofx(17.0)
            clg_cap_f_of_temp.setMaximumValueofx(22.0)
            clg_cap_f_of_temp.setMinimumValueofy(13.0)
            clg_cap_f_of_temp.setMaximumValueofy(46.0)

            clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
            clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
            clg_cap_f_of_flow.setCoefficient2x(0.34053)
            clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
            clg_cap_f_of_flow.setMinimumValueofx(0.75918)
            clg_cap_f_of_flow.setMaximumValueofx(1.13877)

            clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
            clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
            clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
            clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
            clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
            clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
            clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
            clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
            clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
            clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
            clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

            clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
            clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
            clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
            clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
            clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
            clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

            clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
            clg_part_load_ratio.setCoefficient1Constant(0.77100)
            clg_part_load_ratio.setCoefficient2x(0.22900)
            clg_part_load_ratio.setCoefficient3xPOW2(0.0)
            clg_part_load_ratio.setMinimumValueofx(0.0)
            clg_part_load_ratio.setMaximumValueofx(1.0)

            clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
            clg_cap_f_of_temp_low_spd.setCoefficient1Constant(0.42415)
            clg_cap_f_of_temp_low_spd.setCoefficient2x(0.04426)
            clg_cap_f_of_temp_low_spd.setCoefficient3xPOW2(-0.00042)
            clg_cap_f_of_temp_low_spd.setCoefficient4y(0.00333)
            clg_cap_f_of_temp_low_spd.setCoefficient5yPOW2(-0.00008)
            clg_cap_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00021)
            clg_cap_f_of_temp_low_spd.setMinimumValueofx(17.0)
            clg_cap_f_of_temp_low_spd.setMaximumValueofx(22.0)
            clg_cap_f_of_temp_low_spd.setMinimumValueofy(13.0)
            clg_cap_f_of_temp_low_spd.setMaximumValueofy(46.0)

            clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
            clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient1Constant(1.23649)
            clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient2x(-0.02431)
            clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient3xPOW2(0.00057)
            clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient4y(-0.01434)
            clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient5yPOW2(0.00063)
            clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00038)
            clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofx(17.0)
            clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofx(22.0)
            clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofy(13.0)
            clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofy(46.0)

            clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model,
                                                                    model.alwaysOnDiscreteSchedule,
                                                                    clg_cap_f_of_temp,
                                                                    clg_cap_f_of_flow,
                                                                    clg_energy_input_ratio_f_of_temp,
                                                                    clg_energy_input_ratio_f_of_flow,
                                                                    clg_part_load_ratio,
                                                                    clg_cap_f_of_temp_low_spd,
                                                                    clg_energy_input_ratio_f_of_temp_low_spd)

            clg_coil.setName("#{zone.name} PTHP 2spd DX AC Clg Coil")
            clg_coil.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new(0.69))
            clg_coil.setBasinHeaterCapacity(10)
            clg_coil.setBasinHeaterSetpointTemperature(2.0)

          elsif cooling_type == "Single Speed DX AC"   # for small hotel

            clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
            clg_cap_f_of_temp.setCoefficient1Constant(0.942587793)
            clg_cap_f_of_temp.setCoefficient2x(0.009543347)
            clg_cap_f_of_temp.setCoefficient3xPOW2(0.000683770)
            clg_cap_f_of_temp.setCoefficient4y(-0.011042676)
            clg_cap_f_of_temp.setCoefficient5yPOW2(0.000005249)
            clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.000009720)
            clg_cap_f_of_temp.setMinimumValueofx(12.77778)
            clg_cap_f_of_temp.setMaximumValueofx(23.88889)
            clg_cap_f_of_temp.setMinimumValueofy(18.3)
            clg_cap_f_of_temp.setMaximumValueofy(46.11111)

            clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
            clg_cap_f_of_flow.setCoefficient1Constant(0.8)
            clg_cap_f_of_flow.setCoefficient2x(0.2)
            clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
            clg_cap_f_of_flow.setMinimumValueofx(0.5)
            clg_cap_f_of_flow.setMaximumValueofx(1.5)

            clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
            clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.342414409)
            clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.034885008)
            clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000623700)
            clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.004977216)
            clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000437951)
            clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000728028)
            clg_energy_input_ratio_f_of_temp.setMinimumValueofx(12.77778)
            clg_energy_input_ratio_f_of_temp.setMaximumValueofx(23.88889)
            clg_energy_input_ratio_f_of_temp.setMinimumValueofy(18.3)
            clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.11111)

            clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
            clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.1552)
            clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1808)
            clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
            clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
            clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

            clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
            clg_part_load_ratio.setCoefficient1Constant(0.85)
            clg_part_load_ratio.setCoefficient2x(0.15)
            clg_part_load_ratio.setCoefficient3xPOW2(0.0)
            clg_part_load_ratio.setMinimumValueofx(0.0)
            clg_part_load_ratio.setMaximumValueofx(1.0)
            clg_part_load_ratio.setMinimumCurveOutput(0.7)
            clg_part_load_ratio.setMaximumCurveOutput(1.0)

            clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                       model.alwaysOnDiscreteSchedule,
                                                                       clg_cap_f_of_temp,
                                                                       clg_cap_f_of_flow,
                                                                       clg_energy_input_ratio_f_of_temp,
                                                                       clg_energy_input_ratio_f_of_flow,
                                                                       clg_part_load_ratio)

            clg_coil.setName("#{zone.name} PTHP 1spd DX AC Clg Coil")
            
          elsif cooling_type == "Water"
            clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
            clg_coil.setName("#{zone.name} PTHP 1spd DX AC Clg Coil")
          else
            OpenStudio::logFree(OpenStudio::Warn, 'openstudio.model.Model', "pthp_cooling_type of #{cooling_type} is not recognized.")
          end
          
          unless chilled_water_loop.nil?
            chilled_water_loop.addDemandBranchForComponent(clg_coil)
          end

          pthp_system = OpenStudio::Model::ZoneHVACPackagedTerminalHeatPump.new(model,
                                                                                model.alwaysOnDiscreteSchedule, 
                                                                                fan,
                                                                                htg_coil,
                                                                                clg_coil,
                                                                                supplemental_htg_coil)

          pthp_system.setName("#{zone.name} PTHP")
          if fan_type == "ConstantVolume"
            pthp_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOnDiscreteSchedule)
          elsif fan_type == "Cycling"
            pthp_system.setSupplyAirFanOperatingModeSchedule(always_off)
          end
          pthp_system.addToThermalZone(zone)

          pthps << pthp_system
          
        end

        return pthps
        
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
  def self.add_pvav_pfp_boxes(model,
              standard, 
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
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model.add_schedule(hvac_op_sch)
    end
    
    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model.add_schedule(oa_damper_sch)
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

    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),clg_sa_temp_c)

    #air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV with PFP Boxes and Reheat")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,sa_temp_sch)
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
    fan = OpenStudio::Model::FanVariableVolume.new(model,model.alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.setFanEfficiency(vav_fan_efficiency)
    fan.setMotorEfficiency(vav_fan_motor_efficiency)
    fan.setPressureRise(vav_fan_pressure_rise)
    fan.setFanPowerMinimumFlowRateInputMethod('fraction')
    fan.setFanPowerMinimumFlowFraction(0.25)
    fan.addToNode(air_loop.supplyInletNode)
    fan.setEndUseSubcategory("VAV system Fans")

    #heating coil
    htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model,model.alwaysOnDiscreteSchedule)
    htg_coil.setName("#{air_loop.name} Htg Coil")
    htg_coil.addToNode(air_loop.supplyInletNode)

    # Cooling coil
    clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model)
    clg_coil.setName("#{air_loop.name} Clg Coil")
    clg_coil.addToNode(air_loop.supplyInletNode)

    #outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    #oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system need to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    #hook the VAV system to each zone
    thermal_zones.each do |zone|

      #reheat coil
      rht_coil = OpenStudio::Model::CoilHeatingElectric.new(model,model.alwaysOnDiscreteSchedule)
      rht_coil.setName("#{zone.name} Rht Coil")

      # terminal fan
      pfp_fan = OpenStudio::Model::FanConstantVolume.new(model,model.alwaysOnDiscreteSchedule)
      pfp_fan.setName("#{zone.name} PFP Term Fan")
      pfp_fan.setPressureRise(300)
      
      #parallel fan powered terminal
      pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(model,
                                                                                  model.alwaysOnDiscreteSchedule,
                                                                                  pfp_fan,
                                                                                  rht_coil)
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