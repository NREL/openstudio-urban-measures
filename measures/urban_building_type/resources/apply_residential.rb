
def apply_residential_location(model, runner)

  runner.registerInfo("Applying residential location.")
  
  measure = SetResidentialEPWFile.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true

end

def apply_residential_occupancy(model, runner)

  runner.registerInfo("Applying residential occupancy.")  
	
  measure = AddResidentialBedroomsAndBathrooms.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true	
	
end

def apply_residential_foundations(model, standards_space_type, basement_thermal_zone, runner)

  runner.registerInfo("Applying residential foundation constructions.")

  case standards_space_type
  when "Single-Family"
  
    if not basement_thermal_zone.nil?
      measure = ProcessConstructionsFoundationsFloorsBasementFinished.new
      args_hash = default_args_hash(model, measure)
      run_measure(model, measure, args_hash, runner)		
    else
      measure = ProcessConstructionsFoundationsFloorsSlab.new
      args_hash = default_args_hash(model, measure)
      run_measure(model, measure, args_hash, runner)
    end  
	
  when "Multifamily (2 to 4 units)"   
  
    if not basement_thermal_zone.nil?
      measure = ProcessConstructionsFoundationsFloorsBasementFinished.new
      args_hash = default_args_hash(model, measure)
      run_measure(model, measure, args_hash, runner)		
    else
      measure = ProcessConstructionsFoundationsFloorsSlab.new
      args_hash = default_args_hash(model, measure)
      run_measure(model, measure, args_hash, runner)
    end   
  
  when "Multifamily (5 or more units)"  
  
    if not basement_thermal_zone.nil?
      measure = ProcessConstructionsFoundationsFloorsBasementFinished.new
      args_hash = default_args_hash(model, measure)
      run_measure(model, measure, args_hash, runner)		
    else
      measure = ProcessConstructionsFoundationsFloorsSlab.new
      args_hash = default_args_hash(model, measure)
      run_measure(model, measure, args_hash, runner)
    end    
  
  when "Mobile Home"
    runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
    return false
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
  return true	
	
end

def apply_residential_floors(model, runner)

  runner.registerInfo("Applying residential floor constructions.")
    
  measure = ProcessConstructionsFoundationsFloorsCovering.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)

  measure = ProcessConstructionsFoundationsFloorsThermalMass.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true	
	
end

def apply_residential_ceilings(model, standards_space_type, runner)

  runner.registerInfo("Applying residential ceiling constructions.")

  case standards_space_type
  when "Single-Family"
	
    measure = ProcessConstructionsCeilingsRoofsFinishedRoof.new # TODO: this should be unfinished attic
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
    measure = ProcessConstructionsCeilingsRoofsRoofingMaterial.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
    measure = ProcessConstructionsCeilingsRoofsThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)     
	
  when "Multifamily (2 to 4 units)"

    measure = ProcessConstructionsCeilingsRoofsFinishedRoof.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
    measure = ProcessConstructionsCeilingsRoofsRoofingMaterial.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner) 

    measure = ProcessConstructionsCeilingsRoofsThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)     
  
  when "Multifamily (5 or more units)"

    measure = ProcessConstructionsCeilingsRoofsFinishedRoof.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
    measure = ProcessConstructionsCeilingsRoofsRoofingMaterial.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner) 
    
    measure = ProcessConstructionsCeilingsRoofsThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)     
  
  when "Mobile Home"
    runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
    return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
  return true	
	
end

def apply_residential_walls(model, standards_space_type, runner)

  runner.registerInfo("Applying residential wall constructions.")
  
  case standards_space_type
  when "Single-Family"
		
    measure = ProcessConstructionsWallsExteriorWoodStud.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
    measure = ProcessConstructionsWallsSheathing.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsExteriorFinish.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsExteriorThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsPartitionThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)    
	
  when "Multifamily (2 to 4 units)"	
  
    measure = ProcessConstructionsWallsExteriorCMU.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsSheathing.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsExteriorFinish.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsExteriorThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsPartitionThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)   	
  
  when "Multifamily (5 or more units)"
  
    measure = ProcessConstructionsWallsExteriorCMU.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
    measure = ProcessConstructionsWallsSheathing.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsExteriorFinish.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsExteriorThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsWallsPartitionThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)     
  
  when "Mobile Home"
    runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
    return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end 
  
  return true	
	
end

def apply_residential_uninsulated_surfaces(model, runner)

  runner.registerInfo("Applying residential uninsulated surface constructions.")
	
  measure = ProcessConstructionsUninsulatedSurfaces.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)    
  
  return true	  
  
end

def apply_residential_fenestration(model, runner)

  runner.registerInfo("Applying residential window constructions.")
	
  measure = ProcessConstructionsWindows.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true	
	
end

def apply_residential_appliances(model, runner)

  runner.registerInfo("Applying residential appliances.")
	
  measure = ResidentialRefrigerator.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  measure = ResidentialCookingRange.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  measure = ResidentialDishwasher.new
  args_hash = default_args_hash(model, measure)  
  run_measure(model, measure, args_hash, runner)
  
  measure = ResidentialClothesWasher.new
  args_hash = default_args_hash(model, measure)   
  run_measure(model, measure, args_hash, runner)
  
  measure = ResidentialClothesDryer.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true	

end

def apply_residential_lighting(model, runner)

  runner.registerInfo("Applying residential lighting.")

  measure = ResidentialLighting.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true	

end

def apply_residential_plugloads(model, runner)

  runner.registerInfo("Applying residential plug loads.")

  measure = ResidentialMiscellaneousElectricLoads.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true

end

def apply_residential_hvac(model, standards_space_type, runner)

  runner.registerInfo("Applying residential HVAC.")
  
  case standards_space_type
  when "Single-Family"
    
    measure = ProcessFurnaceFuel.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
	
    measure = ProcessSingleSpeedCentralAirConditioner.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)	
    
    measure = ProcessHeatingSetpoints.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessCoolingSetpoints.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
  when "Multifamily (2 to 4 units)"

    measure = ProcessFurnaceFuel.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessRoomAirConditioner.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
    measure = ProcessHeatingSetpoints.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessCoolingSetpoints.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)    
  
  when "Multifamily (5 or more units)"

    measure = ProcessBoilerFuel.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessRoomAirConditioner.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)	
  
    measure = ProcessHeatingSetpoints.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessCoolingSetpoints.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)  
  
  when "Mobile Home"
    runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
    return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end  
  
  return true
  
end

def apply_residential_dhw(model, runner)

  runner.registerInfo("Applying residential DHW.")
  
  measure = ResidentialHotWaterHeaterTankFuel.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true

end

def apply_residential_airflow(model, runner)

  runner.registerInfo("Applying residential airflow.")
    
  measure = ResidentialAirflow.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true	
	
end

def run_measure(model, measure, args_hash, runner)
  # get arguments
  arguments = measure.arguments(model)
  argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

  # populate argument with specified hash value if specified
  arguments.each do |arg|
    temp_arg_var = arg.clone
    if args_hash[arg.name]
      if !temp_arg_var.setValue(args_hash[arg.name])
        runner.registerError("Failed to set argument value #{args_hash[arg.name]} for #{arg.name} in measure #{measure.name}")
        raise("Failed to set argument value #{args_hash[arg.name]} for #{arg.name} in measure #{measure.name}")
      end
    end
    argument_map[arg.name] = temp_arg_var
  end

  # run the measure
  test = measure.run(model, runner, argument_map)

  if !test
    runner.registerError("Failed to run measure #{measure.name}")
  end
end

def default_args_hash(model, measure)
	args_hash = {}
	arguments = measure.arguments(model)
	arguments.each do |arg|	
		if arg.hasDefaultValue
			type = arg.type.valueName
			case type
			when "Boolean"
				args_hash[arg.name] = arg.defaultValueAsBool
			when "Double"
				args_hash[arg.name] = arg.defaultValueAsDouble
			when "Integer"
				args_hash[arg.name] = arg.defaultValueAsInteger
			when "String"
				args_hash[arg.name] = arg.defaultValueAsString
			when "Choice"
				args_hash[arg.name] = arg.defaultValueAsString
			end
		else
			args_hash[arg.name] = nil
		end
	end
	return args_hash
end

def get_thermal_zones(model)

  living_thermal_zones = []
  basement_thermal_zone = nil
  model.getThermalZones.each do |thermal_zone|
    if thermal_zone.name.to_s.include? "Story 0 Space"
      basement_thermal_zone = thermal_zone
    else
      living_thermal_zones << thermal_zone
    end
  end  
  
  return living_thermal_zones, basement_thermal_zone
  
end

def apply_new_residential_hvac(model, runner, heating_source, cooling_source, building_type)

    heating_cooling = "#{heating_source}_#{cooling_source}"
    
    case heating_cooling
    when "Gas_Electric"
    
      # [1] PLANT LOOPS
          # [1] Hot Water Plant Loop with:
              # [1] Boiler on Supply Side
              # [1] Coil Heating Water on Demand Side
          # [0] Chilled Water Plant Loop
      # [1] ZONE EQUIPMENT
          # [1] Packaged Terminal Air Conditioner on each zone (Living/Basement) with:
              # [1] Coil Heating Water
              # [1] Coil Cooling DX Single Speed
      
      fan_type = "ConstantVolume" # ConstantVolume, Cycling
      heating_type = "Water" # Gas, Electric, Water
      cooling_type = "Single Speed DX AC" # Two Speed DX AC, Single Speed DX AC
      
      hot_water_loop = model.add_hw_loop('NaturalGas')
      
      model.add_ptac(nil, 
                     nil,
                     hot_water_loop,
                     HelperMethods.zones_with_thermostats(model.getThermalZones),
                     fan_type,
                     heating_type,
                     cooling_type)
                     
      equip_applied = "PTAC"
    
    when "Electric_Electric"
    
      # [0] PLANT LOOPS
          # [0] Hot Water Plant Loop
          # [0] Chilled Water Plant Loop
      # [1] ZONE EQUIPMENT
          # [1] Packaged Terminal Heat Pump on each zone (Living/Basement) with:
              # [1] Coil Heating DX Single Speed
              # [1] Coil Cooling DX Single Speed
              # [1] Supplemental Coil Heating Electric
  
      fan_type = "ConstantVolume" # ConstantVolume, Cycling
      heating_type = nil
      cooling_type = "Single Speed DX AC" # Two Speed DX AC, Single Speed DX AC
  
      HelperMethods.add_pthp(model, 
                             HelperMethods.zones_with_thermostats(model.getThermalZones),
                             fan_type,
                             heating_type,
                             cooling_type)
                             
      equip_applied = "PTHP"
    
    when "District Hot Water_Electric"
    
      # [1] PLANT LOOPS
          # [1] Hot Water Plant Loop with:
              # [1] District on Supply Side
              # [1] Coil Heating Water on Demand Side
          # [0] Chilled Water Plant Loop
      # [1] ZONE EQUIPMENT
          # [1] Packaged Terminal Air Conditioner on each zone (Living/Basement) with:
              # [1] Coil Heating Water
              # [1] Coil Cooling DX Single Speed            
  
      fan_type = "ConstantVolume" # ConstantVolume, Cycling
      heating_type = "Water" # Gas, Electric, Water
      cooling_type = "Single Speed DX AC" # Two Speed DX AC, Single Speed DX AC
      
      hot_water_loop = model.add_hw_loop('NaturalGas')
      hot_water_loop = HelperMethods.make_district_hot_water_loop(model, runner, hot_water_loop)
      
      model.add_ptac(nil, 
                     nil,
                     hot_water_loop,
                     HelperMethods.zones_with_thermostats(model.getThermalZones),
                     fan_type,
                     heating_type,
                     cooling_type)

      equip_applied = "PTAC"
  
    when "District Ambient Water_District Ambient Water"
  
      # [1] PLANT LOOPS
          # [1] Heat Pump Loop with:
              # [1] District Heating on Supply Side
              # [1] District Cooling on Supply Side
              # [1] Coil Heating Water To Air Heat Pump Equation Fit on Demand Side
              # [1] Coil Cooling Water To Air Heat Pump Equation Fit on Demand Side
          # [0] Hot Water Plant Loop
          # [0] Chilled Water Plant Loop
      # [1] ZONE EQUIPMENT
          # [1] Water To Air Heat Pump on each zone (Living/Basement) with:
              # [1] Coil Heating Water To Air Heat Pump Equation Fit
              # [1] Coil Cooling Water To Air Heat Pump Equation Fit
              # [1] Supplemental Coil Heating Electric
      
      heat_pump_loop = model.add_hp_loop()
      heat_pump_loop = HelperMethods.make_district_heat_pump_loop(model, runner, heat_pump_loop)    
  
      HelperMethods.add_watertoairhp(model,
                                     heat_pump_loop,
                                     HelperMethods.zones_with_thermostats(model.getThermalZones))
    
      equip_applied = "Water-to-Air HP"
    
    when "Gas_District Chilled Water"
    
      # [2] PLANT LOOPS
          # [1] Hot Water Plant Loop with:
              # [1] Boiler on Supply Side
              # [1] Coil Heating Water on Demand Side
          # [1] Chilled Water Plant Loop with:
              # [1] District on Supply Side
              # [1] Coil Cooling Water on Demand Side
      # [1] ZONE EQUIPMENT
          # [1] Four Pipe Fan Coil on each zone (Living/Basement) with:
              # [1] Coil Heating Water
              # [1] Coil Cooling Water      
      
      chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
      chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
      chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
      chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
      chiller_capacity_guess = nil
      
      vav_operation_schedule = nil
      doas_oa_damper_schedule = nil
      doas_fan_maximum_flow_rate = nil
      doas_economizer_control_type = "FixedDryBulb" # FixedDryBulb
      
      hot_water_loop = model.add_hw_loop('NaturalGas')
      chilled_water_loop = model.add_chw_loop(nil,
                                              chw_pumping_type,
                                              chiller_cooling_type,
                                              chiller_condenser_type,
                                              chiller_compressor_type,
                                              chiller_capacity_guess)
      chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)
                                              
      model.add_doas(nil, 
                     nil,
                     hot_water_loop, 
                     chilled_water_loop,
                     HelperMethods.zones_with_thermostats(model.getThermalZones),
                     vav_operation_schedule,
                     doas_oa_damper_schedule,
                     doas_fan_maximum_flow_rate,
                     doas_economizer_control_type)
    
      equip_applied = "DOAS"
    
    when "Electric_District Chilled Water"
    
      # [1] PLANT LOOPS
          # [0] Hot Water Plant Loop
          # [1] Chilled Water Plant Loop with:
              # [1] District on Supply Side
              # [1] Coil Cooling Water on Demand Side
      # [1] ZONE EQUIPMENT
          # [1] PSZ-AC on each zone (Living/Basement) with:
              # [1] Coil Heating Electric
              # [1] Coil Cooling Water
  
      chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
      chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
      chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
      chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
      chiller_capacity_guess = nil    
  
      fan_position = "BlowThrough" # BlowThrough, DrawThrough
      fan_type = "ConstantVolume" # AP: ConstantVolume
      heating_type = nil # Gas, Water, Single Speed Heat Pump, Water To Air Heat Pump
      supplemental_heating_type = "Electric" # Electric, Gas
      cooling_type = "Water" # Water, Two Speed DX AC, Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump
  
      chilled_water_loop = model.add_chw_loop(nil,
                                              chw_pumping_type,
                                              chiller_cooling_type,
                                              chiller_condenser_type,
                                              chiller_compressor_type,
                                              chiller_capacity_guess)
      chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)    
  
      model.add_psz_ac(nil, 
                       nil, 
                       nil, # Typically nil unless water source hp
                       chilled_water_loop, # Typically nil unless water source hp
                       HelperMethods.zones_with_thermostats(model.getThermalZones), 
                       nil,
                       nil,
                       fan_position, 
                       fan_type,
                       heating_type,
                       supplemental_heating_type,
                       cooling_type)
    
      equip_applied = "PSZ-AC"
    
    when "District Hot Water_District Chilled Water"
    
      # [2] PLANT LOOPS
          # [1] Hot Water Plant Loop with:
              # [1] District on Supply Side
              # [1] Coil Heating Water on Demand Side
          # [1] Chilled Water Plant Loop with:
              # [1] District on Supply Side
              # [1] Coil Cooling Water on Demand Side
      # [1] ZONE EQUIPMENT
          # [1] Four Pipe Fan Coil on each zone (Living/Basement) with:
              # [1] Coil Heating Water
              # [1] Coil Cooling Water      
      
      chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
      chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
      chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
      chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
      chiller_capacity_guess = nil
      
      vav_operation_schedule = nil
      doas_oa_damper_schedule = nil
      doas_fan_maximum_flow_rate = nil
      doas_economizer_control_type = "FixedDryBulb" # FixedDryBulb
      
      hot_water_loop = model.add_hw_loop('NaturalGas')
      hot_water_loop = HelperMethods.make_district_hot_water_loop(model, runner, hot_water_loop)
      chilled_water_loop = model.add_chw_loop(nil,
                                              chw_pumping_type,
                                              chiller_cooling_type,
                                              chiller_condenser_type,
                                              chiller_compressor_type,
                                              chiller_capacity_guess)
      chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)
                                              
      model.add_doas(nil, 
                     nil,
                     hot_water_loop, 
                     chilled_water_loop,
                     HelperMethods.zones_with_thermostats(model.getThermalZones),
                     vav_operation_schedule,
                     doas_oa_damper_schedule,
                     doas_fan_maximum_flow_rate,
                     doas_economizer_control_type)
                     
      equip_applied = "DOAS"

    when "District Ambient Water_Electric"
        runner.registerError("Cooling source '#{cooling_source}' and heating source '#{heating_source}' not supported.")
        return false    
    when "District Ambient Water_District Chilled Water"
      runner.registerError("Cooling source '#{cooling_source}' and heating source '#{heating_source}' not supported.")
      return false    
    when "Gas_District Ambient Water"
      runner.registerError("Cooling source '#{cooling_source}' and heating source '#{heating_source}' not supported.")
      return false    
    when "Electric_District Ambient Water"
      runner.registerError("Cooling source '#{cooling_source}' and heating source '#{heating_source}' not supported.")
      return false    
    when "District Hot Water_District Ambient Water"
      runner.registerError("Cooling source '#{cooling_source}' and heating source '#{heating_source}' not supported.")
      return false    
    end

    puts "#{equip_applied} applied to #{building_type}."
    
    return true
    
end

def apply_residential(model, runner, heating_source, cooling_source)
  
  measures = Dir.entries("./resources/measures/").select {|entry| !(entry == '.' || entry == '..')}
  measures.each do |measure|
    require "./resources/measures/#{measure}/measure.rb"
  end
  
  building_space_type = model.getBuilding.standardsBuildingType.get
  number_of_residential_units = model.getBuilding.standardsNumberOfLivingUnits.get.to_i
  num_spaces = model.getSpaces.length.to_i
  units_per_space = number_of_residential_units.to_f / num_spaces.to_f
  
  # puts building_space_type, number_of_residential_units, num_spaces, units_per_space
  
  if building_space_type == "Single-Family"
    living_zone = nil
    model.getThermalZones.each do |thermal_zone|
      if thermal_zone.name.to_s.include? "Story 1"
        living_zone = thermal_zone
      end
    end
    model.getSpaces.each do |space|
      if !space.thermalZone.get.name.to_s.include? "Story 0" and !space.thermalZone.get.name.to_s.include? "Story 1"
        space.setThermalZone(living_zone) # Set all above-grade spaces to the same thermal zone since this is a single unit, single-family house
      end
    end  
    unit = OpenStudio::Model::BuildingUnit.new(model)
    unit.setBuildingUnitType(Constants.BuildingUnitTypeResidential)
    unit.setName(Constants.ObjectNameBuildingUnit)
    model.getSpaces.each do |space|
      space.setBuildingUnit(unit)
    end
  else
    # TODO: how to split up spaces and assign units to multi-family geometry?
  end
  
  living_thermal_zones, basement_thermal_zone = get_thermal_zones(model)
  
  model.getThermalZones.each do |thermal_zone|
    if thermal_zone.spaces.empty?
      thermal_zone.remove
    end
  end
  
  model.getSpaceTypes.each do |space_type|
    if space_type.spaces.empty?
      space_type.remove
    end
  end  
  
  result = true
  result = result && apply_residential_location(model, runner)
  result = result && apply_residential_occupancy(model, runner)
  result = result && apply_residential_foundations(model, building_space_type, basement_thermal_zone, runner)
  result = result && apply_residential_floors(model, runner)
  result = result && apply_residential_ceilings(model, building_space_type, runner)
  result = result && apply_residential_walls(model, building_space_type, runner)
  result = result && apply_residential_uninsulated_surfaces(model, runner)
  result = result && apply_residential_fenestration(model, runner)
  result = result && apply_residential_hvac(model, building_space_type, runner)
  result = result && apply_residential_dhw(model, runner)
  result = result && apply_residential_appliances(model, runner)
  result = result && apply_residential_lighting(model, runner)
  result = result && apply_residential_plugloads(model, runner)
  result = result && apply_residential_airflow(model, runner)
  
  control_slave_zones_hash = HVAC.get_control_and_slave_zones(model.getThermalZones)
  all_slave_zones = []
  control_slave_zones_hash.each do |control_zone, slave_zones|
    next if slave_zones.empty?
    slave_zones.each do |slave_zone|
      all_slave_zones << slave_zone
    end
  end
  puts "#{building_space_type} has #{control_slave_zones_hash.keys.length} control zone(s) and #{all_slave_zones.length} slave zone(s)."
  
  if heating_source != "NA" or cooling_source != "NA"
    runner.registerInfo("Removing existing HVAC and replacing with heating_source='#{heating_source}' and cooling_source='#{cooling_source}'.")
    HelperMethods.remove_all_hvac_equipment(model, runner)
    runner.registerInfo("Applying HVAC system with heating_source='#{heating_source}' and cooling_source='#{cooling_source}'.")
    result = result && apply_new_residential_hvac(model, runner, heating_source, cooling_source, building_space_type)
  end
  
  runner.registerValue("bldg_use", building_space_type)
  runner.registerValue("res_units", number_of_residential_units, "count")
  runner.registerValue("num_spaces", num_spaces, "spaces")
  runner.registerValue("units_per_space", units_per_space, "unitsperspace")
  
  return result
    
end

