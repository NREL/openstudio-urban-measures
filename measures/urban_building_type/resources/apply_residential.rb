require_relative '../resources/util'
require_relative '../resources/geometry'

def apply_weather(model, runner)

  runner.registerInfo("Applying weather.")
  require './resources/measures/SetResidentialEPWFile/measure.rb'
  
  measure = SetResidentialEPWFile.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true

end

def apply_residential_occupancy(model, standards_space_type, runner)

  runner.registerInfo("Applying residential occupancy.")  
  require './resources/measures/AddResidentialBedroomsAndBathrooms/measure.rb'
    
  case standards_space_type
  when "Single-Family"
	
    measure = AddResidentialBedroomsAndBathrooms.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
  when "Multifamily (2 to 4 units)"	

    measure = AddResidentialBedroomsAndBathrooms.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
  
  when "Multifamily (5 or more units)"

    measure = AddResidentialBedroomsAndBathrooms.new
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

def apply_residential_foundations(model, standards_space_type, basement_thermal_zone, runner)

  runner.registerInfo("Applying residential foundation constructions.")
  require './resources/measures/ProcessConstructionsFoundationsFloorsSlab/measure.rb'
  require './resources/measures/ProcessConstructionsFoundationsFloorsBasementFinished/measure.rb'

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

def apply_residential_floors(model, standards_space_type, runner)

  runner.registerInfo("Applying residential floor constructions.")
  require './resources/measures/ProcessConstructionsFoundationsFloorsCovering/measure.rb'
  require './resources/measures/ProcessConstructionsFoundationsFloorsThermalMass/measure.rb'

  case standards_space_type
  when "Single-Family"
    
    measure = ProcessConstructionsFoundationsFloorsCovering.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsFoundationsFloorsThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)    
	
  when "Multifamily (2 to 4 units)"

    measure = ProcessConstructionsFoundationsFloorsCovering.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsFoundationsFloorsThermalMass.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)    
  
  when "Multifamily (5 or more units)"
    
    measure = ProcessConstructionsFoundationsFloorsCovering.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessConstructionsFoundationsFloorsThermalMass.new
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

def apply_residential_ceilings(model, standards_space_type, runner)

  runner.registerInfo("Applying residential ceiling constructions.")
  require './resources/measures/ProcessConstructionsCeilingsRoofsFinishedRoof/measure.rb'
  require './resources/measures/ProcessConstructionsCeilingsRoofsRoofingMaterial/measure.rb'
  require './resources/measures/ProcessConstructionsCeilingsRoofsThermalMass/measure.rb'

  case standards_space_type
  when "Single-Family"
	
    measure = ProcessConstructionsCeilingsRoofsFinishedRoof.new
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
  require './resources/measures/ProcessConstructionsWallsExteriorWoodStud/measure.rb'
  require './resources/measures/ProcessConstructionsWallsExteriorCMU/measure.rb'
  require './resources/measures/ProcessConstructionsWallsSheathing/measure.rb'
  require './resources/measures/ProcessConstructionsWallsExteriorFinish/measure.rb'
  require './resources/measures/ProcessConstructionsWallsExteriorThermalMass/measure.rb'
  require './resources/measures/ProcessConstructionsWallsPartitionThermalMass/measure.rb'
  
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

def apply_residential_uninsulated_surfaces(model, standards_space_type, runner)

  runner.registerInfo("Applying residential uninsulated surface constructions.")
  require './resources/measures/ProcessConstructionsUninsulatedSurfaces/measure.rb'

  case standards_space_type
  when "Single-Family"
	
    measure = ProcessConstructionsUninsulatedSurfaces.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)    
	
  when "Multifamily (2 to 4 units)"

    measure = ProcessConstructionsUninsulatedSurfaces.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)     
  
  when "Multifamily (5 or more units)"

    measure = ProcessConstructionsUninsulatedSurfaces.new
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

def apply_residential_fenestration(model, standards_space_type, runner)

  runner.registerInfo("Applying residential window constructions.")
  require './resources/measures/ProcessConstructionsWindows/measure.rb'

  case standards_space_type
  when "Single-Family"
	
    measure = ProcessConstructionsWindows.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
	
  when "Multifamily (2 to 4 units)"

    measure = ProcessConstructionsWindows.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner) 	
  
  when "Multifamily (5 or more units)"

    measure = ProcessConstructionsWindows.new
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

def apply_residential_appliances(model, standards_space_type, space, units_per_space, runner)

  runner.registerInfo("Applying residential appliances.")
  require './resources/measures/AddResidentialRefrigerator/measure.rb'
  require './resources/measures/ResidentialCookingRange/measure.rb'
  require './resources/measures/ResidentialDishwasher/measure.rb'
  require './resources/measures/ResidentialClothesWasher/measure.rb'
  require './resources/measures/ResidentialClothesDryer/measure.rb'
  
  case standards_space_type
  when "Single-Family"
	
    measure = ResidentialRefrigerator.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["mult"] = units_per_space
    run_measure(model, measure, args_hash, runner)
    
    measure = ResidentialCookingRange.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["mult"] = units_per_space
    run_measure(model, measure, args_hash, runner)
    
    measure = ResidentialDishwasher.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["mult_e"] = units_per_space
    args_hash["mult_hw"] = units_per_space    
    run_measure(model, measure, args_hash, runner)
    
    measure = ResidentialClothesWasher.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["cw_mult_e"] = units_per_space
    args_hash["cw_mult_hw"] = units_per_space     
    run_measure(model, measure, args_hash, runner)
    
    measure = ResidentialClothesDryer.new
    args_hash = default_args_hash(model, measure)    
    args_hash["space"] = space.name.get
    args_hash["cd_mult"] = units_per_space    
    run_measure(model, measure, args_hash, runner)      

  when "Multifamily (2 to 4 units)"	

    measure = ResidentialRefrigerator.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["mult"] = units_per_space
    run_measure(model, measure, args_hash, runner)
    
    measure = ResidentialCookingRange.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["mult"] = units_per_space
    run_measure(model, measure, args_hash, runner)
        
    measure = ResidentialDishwasher.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["mult_e"] = units_per_space
    args_hash["mult_hw"] = units_per_space
    run_measure(model, measure, args_hash, runner)

    measure = ResidentialClothesWasher.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["cw_mult_e"] = units_per_space
    args_hash["cw_mult_hw"] = units_per_space  
    run_measure(model, measure, args_hash, runner)

    measure = ResidentialClothesDryer.new
    args_hash = default_args_hash(model, measure)    
    args_hash["space"] = space.name.get
    args_hash["cd_mult"] = units_per_space
    run_measure(model, measure, args_hash, runner)    
  
  when "Multifamily (5 or more units)"

    measure = ResidentialRefrigerator.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["mult"] = units_per_space
    run_measure(model, measure, args_hash, runner)
    
    measure = ResidentialCookingRange.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["mult"] = units_per_space    
    run_measure(model, measure, args_hash, runner)
    
    measure = ResidentialDishwasher.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["mult_e"] = units_per_space
    args_hash["mult_hw"] = units_per_space    
    run_measure(model, measure, args_hash, runner)

    measure = ResidentialClothesWasher.new
    args_hash = default_args_hash(model, measure)
    args_hash["space"] = space.name.get
    args_hash["cw_mult_e"] = units_per_space
    args_hash["cw_mult_hw"] = units_per_space     
    run_measure(model, measure, args_hash, runner)

    measure = ResidentialClothesDryer.new
    args_hash = default_args_hash(model, measure)    
    args_hash["space"] = space.name.get
    args_hash["cd_mult"] = units_per_space
    run_measure(model, measure, args_hash, runner)
  
  when "Mobile Home"
    runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
    return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
  return true	

end

def apply_residential_lighting(model, runner)

  runner.registerInfo("Applying residential lighting.")
  require './resources/measures/ResidentialLighting/measure.rb'

  measure = ResidentialLighting.new
  args_hash = default_args_hash(model, measure)
  run_measure(model, measure, args_hash, runner)
  
  return true	

end

def apply_residential_mels(model, standards_space_type, units_per_space, runner)

  runner.registerInfo("Applying residential MELs.")
  require './resources/measures/ResidentialMiscellaneousElectricLoads/measure.rb'
  # require './resources/measures/AddResidentialExtraRefrigerator/measure.rb'
  # require './resources/measures/AddResidentialFreezer/measure.rb'
  # require './resources/measures/AddResidentialGasFireplace/measure.rb'
  # require './resources/measures/AddResidentialGasGrill/measure.rb'
  # require './resources/measures/AddResidentialGasLighting/measure.rb'
  # require './resources/measures/AddResidentialHotTubHeaterElec/measure.rb'
  # require './resources/measures/AddResidentialHotTubHeaterGas/measure.rb'
  # require './resources/measures/AddResidentialHotTubPump/measure.rb'
  # require './resources/measures/AddResidentialPoolHeaterElec/measure.rb'
  # require './resources/measures/AddResidentialPoolHeaterGas/measure.rb'
  # require './resources/measures/AddResidentialPoolHeaterPump/measure.rb'
  # require './resources/measures/AddResidentialWellPump/measure.rb'
  
  case standards_space_type
  when "Single-Family"	

    measure = ResidentialMiscellaneousElectricLoads.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
	
  when "Multifamily (2 to 4 units)"	

    measure = ResidentialMiscellaneousElectricLoads.new
    args_hash = default_args_hash(model, measure)
    args_hash["mult"] = units_per_space
    run_measure(model, measure, args_hash, runner)	
    
    when "Multifamily (5 or more units)"

    measure = ResidentialMiscellaneousElectricLoads.new
    args_hash = default_args_hash(model, measure)
    args_hash["mult"] = units_per_space
    run_measure(model, measure, args_hash, runner)	
  
  when "Mobile Home"
    runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
    return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
  return true

end

def apply_residential_hvac(model, standards_space_type, runner)

  runner.registerInfo("Applying residential HVAC.")
  require './resources/measures/ProcessHeatingandCoolingSetpoints/measure.rb'
  require './resources/measures/ProcessBoiler/measure.rb'
  require './resources/measures/ProcessFurnace/measure.rb'
  require './resources/measures/ProcessCentralAirConditioner/measure.rb'
  require './resources/measures/ProcessRoomAirConditioner/measure.rb'
  # require './resources/measures/AddResidentialDehumidifier/measure.rb'
  
  case standards_space_type
  when "Single-Family"	

    measure = ProcessHeatingandCoolingSetpoints.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
    
    measure = ProcessFurnace.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)
	
    measure = ProcessCentralAirConditioner.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)	
	
  when "Multifamily (2 to 4 units)"	

    measure = ProcessHeatingandCoolingSetpoints.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessFurnace.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessRoomAirConditioner.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)	
  
  when "Multifamily (5 or more units)"

    measure = ProcessHeatingandCoolingSetpoints.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessBoiler.new
    args_hash = default_args_hash(model, measure)
    run_measure(model, measure, args_hash, runner)

    measure = ProcessRoomAirConditioner.new
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

def apply_residential_dhw(model, standards_space_type, living_thermal_zone, runner)

  runner.registerInfo("Applying residential DHW.")
  require './resources/measures/AddOSWaterHeaterMixedStorageGas/measure.rb'

  living_thermal_zone_name = living_thermal_zone.name.get
  
  case standards_space_type
  when "Single-Family"
  
    measure = AddOSWaterHeaterMixedStorageGas.new
    args_hash = default_args_hash(model, measure)
    args_hash["water_heater_location"] = living_thermal_zone_name
    run_measure(model, measure, args_hash, runner)  
  
  when "Multifamily (2 to 4 units)"
 
    measure = AddOSWaterHeaterMixedStorageGas.new
    args_hash = default_args_hash(model, measure)
    args_hash["water_heater_location"] = living_thermal_zone_name
    run_measure(model, measure, args_hash, runner)  
 
  when "Multifamily (5 or more units)"
  
    measure = AddOSWaterHeaterMixedStorageGas.new
    args_hash = default_args_hash(model, measure)
    args_hash["water_heater_location"] = living_thermal_zone_name
    run_measure(model, measure, args_hash, runner)  
  
  when "Mobile Home"
    runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
    return false  
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
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
  model.getSpaces.each do |space|
    if space.name.to_s.include? "Story 0 Space"
      thermal_zone = space.thermalZone.get
      basement_thermal_zone = thermal_zone
    else
      thermal_zone = space.thermalZone.get
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
  
  result = true
  
  building_space_type = model.getBuilding.standardsBuildingType.get
  number_of_residential_units = model.getBuilding.standardsNumberOfLivingUnits.get.to_i
  num_spaces = model.getSpaces.length.to_i
  units_per_space = number_of_residential_units.to_f / num_spaces.to_f
  
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
  
  result = result && apply_weather(model, runner)
  result = result && apply_residential_occupancy(model, building_space_type, runner)
  result = result && apply_residential_foundations(model, building_space_type, basement_thermal_zone, runner)
  result = result && apply_residential_floors(model, building_space_type, runner)
  result = result && apply_residential_ceilings(model, building_space_type, runner)
  result = result && apply_residential_walls(model, building_space_type, runner)
  result = result && apply_residential_uninsulated_surfaces(model, building_space_type, runner)
  result = result && apply_residential_fenestration(model, building_space_type, runner)
  result = result && apply_residential_hvac(model, building_space_type, runner)
  control_slave_zones_hash = Geometry.get_control_and_slave_zones(model)
  all_slave_zones = []
  control_slave_zones_hash.each do |control_zone, slave_zones|
    result = result && apply_residential_dhw(model, building_space_type, control_zone, runner)
    unless slave_zones.empty?
      all_slave_zones += slave_zones
    end
  end
  puts "#{building_space_type} has #{control_slave_zones_hash.keys.length} control zone(s) and #{all_slave_zones.length} slave zone(s)."
  model.getSpaces.each do |space|
    result = result && apply_residential_appliances(model, building_space_type, space, units_per_space, runner)
  end
  result = result && apply_residential_lighting(model, runner)
  result = result && apply_residential_mels(model, building_space_type, units_per_space, runner)
  
  applicable = true
  if heating_source == "NA" and cooling_source == "NA"
    applicable = false
  end
  if applicable
    runner.registerInfo("Removing existing HVAC and replacing with heating_source='#{heating_source}' and cooling_source='#{cooling_source}'.")
    HelperMethods.remove_all_hvac_equipment(model, runner)
    runner.registerInfo("Applying HVAC system with heating_source='#{heating_source}' and cooling_source='#{cooling_source}'.")
    result = result && apply_new_residential_hvac(model, runner, heating_source, cooling_source, building_space_type)
  end
  
  runner.registerValue('bldg_use', building_space_type)
  runner.registerValue('res_units', number_of_residential_units, 'count')
  runner.registerValue('num_spaces', num_spaces, 'spaces')
  runner.registerValue('units_per_space', units_per_space, 'unitsperspace')
  
  return result
    
end

