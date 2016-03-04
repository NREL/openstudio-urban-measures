def apply_residential_space_type(space_type, runner)
  
  if space_type
	  standards_space_type = space_type.standardsSpaceType.get
	  
	  rendering_color = space_type.renderingColor
	  if rendering_color.empty?
		rendering_color = OpenStudio::Model::RenderingColor.new(space_type.model)
		space_type.setRenderingColor(rendering_color)
	  else
		rendering_color = rendering_color.get
	  end
	  
	  case standards_space_type
	  when "Single-Family"
		rendering_color.setRGB(0, 0, 0)	
	  when "Multifamily (2 to 4 units)"
		rendering_color.setRGB(0, 0, 0)
	  when "Multifamily (5 or more units)"
		rendering_color.setRGB(0, 0, 0)
	  when "Mobile Home"
		rendering_color.setRGB(0, 0, 0)         
	  else
		runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
	  end
  end
  
  return true
end

def apply_residential_constructions(model, living_space_type, basement_space_type, runner)

  runner.registerInfo("Applying residential constructions.")
  require './resources/measures/ProcessConstructionsExteriorInsulatedWallsWoodStud/measure.rb'
  require './resources/measures/ProcessConstructionsExteriorInsulatedWallsCMU/measure.rb'
  require './resources/measures/ProcessConstructionsInteriorUninsulatedWalls/measure.rb'
  require './resources/measures/ProcessConstructionsInteriorUninsulatedFloors/measure.rb'
  require './resources/measures/ProcessConstructionsSlab/measure.rb'
  require './resources/measures/ProcessConstructionsFinishedBasement/measure.rb'
  require './resources/measures/ProcessConstructionsInsulatedRoof/measure.rb'
  require './resources/measures/ProcessConstructionsWindows/measure.rb'
  
  living_space_type_name = living_space_type.name.get
  unless basement_space_type.nil?
	basement_space_type_name = basement_space_type.name.get
  end
  standards_space_type = living_space_type.standardsSpaceType.get

  case standards_space_type
  when "Single-Family"
		
	measure = ProcessConstructionsExteriorInsulatedWallsWoodStud.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	run_measure(model, measure, args_hash, runner)

	measure = ProcessConstructionsInteriorUninsulatedWalls.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	run_measure(model, measure, args_hash, runner)

	measure = ProcessConstructionsInteriorUninsulatedFloors.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	if basement_space_type_name
		args_hash["fbasement_space_type"] = basement_space_type_name
	end
	run_measure(model, measure, args_hash, runner)
	
	if basement_space_type_name
		measure = ProcessConstructionsFinishedBasement.new
		args_hash = default_args_hash(model, measure)
		args_hash["living_space_type"] = living_space_type_name
		args_hash["fbasement_space_type"] = basement_space_type_name
		run_measure(model, measure, args_hash, runner)		
	else
		measure = ProcessConstructionsSlab.new
		args_hash = default_args_hash(model, measure)
		args_hash["living_space_type"] = living_space_type_name
		run_measure(model, measure, args_hash, runner)
	end

	measure = ProcessConstructionsInsulatedRoof.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	run_measure(model, measure, args_hash, runner)	
	
	measure = ProcessConstructionsWindows.new
	args_hash = default_args_hash(model, measure)
	run_measure(model, measure, args_hash, runner) 	
	
  when "Multifamily (2 to 4 units)"	
  
    measure = ProcessConstructionsExteriorInsulatedWallsCMU.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	puts args_hash
	run_measure(model, measure, args_hash, runner)

	measure = ProcessConstructionsInteriorUninsulatedWalls.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	run_measure(model, measure, args_hash, runner)

	measure = ProcessConstructionsInteriorUninsulatedFloors.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	if basement_space_type_name
		args_hash["fbasement_space_type"] = basement_space_type_name
	end
	run_measure(model, measure, args_hash, runner)

	if basement_space_type_name
		measure = ProcessConstructionsFinishedBasement.new
		args_hash = default_args_hash(model, measure)
		args_hash["living_space_type"] = living_space_type_name
		args_hash["fbasement_space_type"] = basement_space_type_name
		run_measure(model, measure, args_hash, runner)		
	else
		measure = ProcessConstructionsSlab.new
		args_hash = default_args_hash(model, measure)
		args_hash["living_space_type"] = living_space_type_name
		run_measure(model, measure, args_hash, runner)
	end	
	
	measure = ProcessConstructionsInsulatedRoof.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	run_measure(model, measure, args_hash, runner)	
	
	measure = ProcessConstructionsWindows.new
	args_hash = default_args_hash(model, measure)
	run_measure(model, measure, args_hash, runner)  	
  
  when "Multifamily (5 or more units)"
  
	measure = ProcessConstructionsExteriorInsulatedWallsCMU.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	run_measure(model, measure, args_hash, runner)

	measure = ProcessConstructionsInteriorUninsulatedWalls.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	run_measure(model, measure, args_hash, runner)

	measure = ProcessConstructionsInteriorUninsulatedFloors.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	if basement_space_type_name
		args_hash["fbasement_space_type"] = basement_space_type_name
	end
	run_measure(model, measure, args_hash, runner)

	if basement_space_type_name
		measure = ProcessConstructionsFinishedBasement.new
		args_hash = default_args_hash(model, measure)
		args_hash["living_space_type"] = living_space_type_name
		args_hash["fbasement_space_type"] = basement_space_type_name
		run_measure(model, measure, args_hash, runner)		
	else
		measure = ProcessConstructionsSlab.new
		args_hash = default_args_hash(model, measure)
		args_hash["living_space_type"] = living_space_type_name
		run_measure(model, measure, args_hash, runner)
	end	
	
	measure = ProcessConstructionsInsulatedRoof.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
	run_measure(model, measure, args_hash, runner)	
	
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

def apply_residential_characteristics(model, space_type, runner)

  runner.registerInfo("Applying residential characteristics.")  
  require './resources/measures/AddResidentialBedroomsAndBathrooms/measure.rb'

  if not model.getBuilding.standardsNumberOfLivingUnits.empty?
	units = model.getBuilding.standardsNumberOfLivingUnits.get.to_f
  end
  
  space_type_name = space_type.name.get
  standards_space_type = space_type.standardsSpaceType.get
  
  case standards_space_type
  when "Single-Family"	
	
	measure = AddResidentialBedroomsAndBathrooms.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = space_type_name
	# args_hash["Num_Br"] = (args_hash["Num_Br"].to_f * units).to_i.to_s
	# args_hash["Num_Ba"] = (args_hash["Num_Ba"].to_f * units).to_i.to_s
	run_measure(model, measure, args_hash, runner)
	
  when "Multifamily (2 to 4 units)"	

	measure = AddResidentialBedroomsAndBathrooms.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = space_type_name
	# args_hash["Num_Br"] = (args_hash["Num_Br"].to_f * units).to_i.to_s
	# args_hash["Num_Ba"] = (args_hash["Num_Ba"].to_f * units).to_i.to_s
	run_measure(model, measure, args_hash, runner)
  
  when "Multifamily (5 or more units)"

	measure = AddResidentialBedroomsAndBathrooms.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = space_type_name
	# args_hash["Num_Br"] = (args_hash["Num_Br"].to_f * units).to_i.to_s
	# args_hash["Num_Ba"] = (args_hash["Num_Ba"].to_f * units).to_i.to_s
	run_measure(model, measure, args_hash, runner)
  
  when "Mobile Home"
	runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
	return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
  return true	
	
end

def apply_residential_appliances(model, space_type, runner)

  runner.registerInfo("Applying residential appliances.")
  require './resources/measures/AddResidentialRefrigerator/measure.rb'
  require './resources/measures/ResidentialCookingRange/measure.rb'  

  space_type_name = space_type.name.get
  standards_space_type = space_type.standardsSpaceType.get
  
  case standards_space_type
  when "Single-Family"	
	
	measure = ResidentialRefrigerator.new
	args_hash = default_args_hash(model, measure)
	args_hash["space_type"] = space_type_name
	run_measure(model, measure, args_hash, runner)
	
	measure = ResidentialCookingRange.new
	args_hash = default_args_hash(model, measure)
	args_hash["space_type"] = space_type_name
	run_measure(model, measure, args_hash, runner)	
	
  when "Multifamily (2 to 4 units)"	

	measure = ResidentialRefrigerator.new
	args_hash = default_args_hash(model, measure)
	args_hash["space_type"] = space_type_name
	run_measure(model, measure, args_hash, runner)
	
	measure = ResidentialCookingRange.new
	args_hash = default_args_hash(model, measure)
	args_hash["space_type"] = space_type_name
	run_measure(model, measure, args_hash, runner)	
  
  when "Multifamily (5 or more units)"

	measure = ResidentialRefrigerator.new
	args_hash = default_args_hash(model, measure)
	args_hash["space_type"] = space_type_name
	run_measure(model, measure, args_hash, runner)
	
	measure = ResidentialCookingRange.new
	args_hash = default_args_hash(model, measure)
	args_hash["space_type"] = space_type_name
	run_measure(model, measure, args_hash, runner)	
  
  when "Mobile Home"
	runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
	return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
  return true	

end

def apply_residential_lighting(model, living_space_type, basement_space_type, runner)

  runner.registerInfo("Applying residential lighting.")
  require './resources/measures/ResidentialLighting/measure.rb'

  living_space_type_name = living_space_type.name.get
  unless basement_space_type.nil?
	basement_space_type_name = basement_space_type.name.get
  end
  standards_space_type = living_space_type.standardsSpaceType.get
  
  case standards_space_type
  when "Single-Family"	

	measure = ResidentialLighting.new
	args_hash = default_args_hash(model, measure)
	args_hash["selected_ltg"] = "Benchmark"
	args_hash["living_space_type"] = living_space_type_name	
	if basement_space_type_name
		args_hash["fbasement_space_type"] = basement_space_type_name
	end
	run_measure(model, measure, args_hash, runner)
	
  when "Multifamily (2 to 4 units)"	

	measure = ResidentialLighting.new
	args_hash = default_args_hash(model, measure)
	args_hash["selected_ltg"] = "Benchmark"
	args_hash["living_space_type"] = living_space_type_name	
	if basement_space_type_name
		args_hash["fbasement_space_type"] = basement_space_type_name
	end
	run_measure(model, measure, args_hash, runner)	
  
  when "Multifamily (5 or more units)"

	measure = ResidentialLighting.new
	args_hash = default_args_hash(model, measure)
	args_hash["selected_ltg"] = "Benchmark"
	args_hash["living_space_type"] = living_space_type_name	
	if basement_space_type_name
		args_hash["fbasement_space_type"] = basement_space_type_name
	end
	run_measure(model, measure, args_hash, runner)	
  
  when "Mobile Home"
	runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
	return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
  return true	

end

def apply_residential_mels(model, living_space_type, basement_space_type, runner)

  runner.registerInfo("Applying residential MELs.")
  require './resources/measures/ResidentialMiscellaneousElectricLoads/measure.rb'

  living_space_type_name = living_space_type.name.get
  unless basement_space_type.nil?
	basement_space_type_name = basement_space_type.name.get
  end  
  standards_space_type = living_space_type.standardsSpaceType.get
  
  case standards_space_type
  when "Single-Family"	

	measure = ResidentialMiscellaneousElectricLoads.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
    if basement_space_type_name
	  args_hash["fbasement_space_type"] = basement_space_type_name
    end		
	run_measure(model, measure, args_hash, runner)
	
  when "Multifamily (2 to 4 units)"	

	measure = ResidentialMiscellaneousElectricLoads.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name	
    if basement_space_type_name
	  args_hash["fbasement_space_type"] = basement_space_type_name
    end			
	run_measure(model, measure, args_hash, runner)	
  
  when "Multifamily (5 or more units)"

	measure = ResidentialMiscellaneousElectricLoads.new
	args_hash = default_args_hash(model, measure)
	args_hash["living_space_type"] = living_space_type_name
    if basement_space_type_name
	  args_hash["fbasement_space_type"] = basement_space_type_name
    end	
	run_measure(model, measure, args_hash, runner)	
  
  when "Mobile Home"
	runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
	return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
  return true

end

def apply_residential_hvac(model, living_space_type, living_thermal_zone, basement_thermal_zone, runner)

  runner.registerInfo("Applying residential HVAC.")
  require './resources/measures/ProcessHeatingandCoolingSetpoints/measure.rb'
  require './resources/measures/ProcessElectricBaseboard/measure.rb'
  require './resources/measures/ProcessFurnace/measure.rb'
  require './resources/measures/ProcessCentralAirConditioner/measure.rb'  

  living_thermal_zone_name = living_thermal_zone.name.get
  unless basement_thermal_zone.nil?
	basement_thermal_zone_name = basement_thermal_zone.name.get
  end
  standards_space_type = living_space_type.standardsSpaceType.get
  
  case standards_space_type
  when "Single-Family"	

    measure = ProcessHeatingandCoolingSetpoints.new
    args_hash = default_args_hash(model, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    run_measure(model, measure, args_hash, runner)

    # TODO: do we want to add a thermostat to the basement?
    if basement_thermal_zone  
        measure = ProcessHeatingandCoolingSetpoints.new
        args_hash = default_args_hash(model, measure)
        args_hash["living_thermal_zone"] = basement_thermal_zone_name
        run_measure(model, measure, args_hash, runner)
    end
    
    measure = ProcessFurnace.new
    args_hash = default_args_hash(model, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    if basement_thermal_zone
	  args_hash["fbasement_thermal_zone"] = basement_thermal_zone_name
    end	
    run_measure(model, measure, args_hash, runner)
	
    measure = ProcessCentralAirConditioner.new
    args_hash = default_args_hash(model, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    if basement_thermal_zone
	  args_hash["fbasement_thermal_zone"] = basement_thermal_zone_name
    end	
    run_measure(model, measure, args_hash, runner)	
	
  when "Multifamily (2 to 4 units)"	

    measure = ProcessHeatingandCoolingSetpoints.new
    args_hash = default_args_hash(model, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    run_measure(model, measure, args_hash, runner)
    
    # TODO: do we want to add a thermostat to the basement?
    if basement_thermal_zone  
        measure = ProcessHeatingandCoolingSetpoints.new
        args_hash = default_args_hash(model, measure)
        args_hash["living_thermal_zone"] = basement_thermal_zone_name
        run_measure(model, measure, args_hash, runner)
    end   

    measure = ProcessElectricBaseboard.new
    args_hash = default_args_hash(model, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    if basement_thermal_zone
	  args_hash["fbasement_thermal_zone"] = basement_thermal_zone_name
    end
    run_measure(model, measure, args_hash, runner)

    measure = ProcessCentralAirConditioner.new
    args_hash = default_args_hash(model, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    if basement_thermal_zone
	  args_hash["fbasement_thermal_zone"] = basement_thermal_zone_name
    end	
    run_measure(model, measure, args_hash, runner)	
  
  when "Multifamily (5 or more units)"

    measure = ProcessHeatingandCoolingSetpoints.new
    args_hash = default_args_hash(model, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    run_measure(model, measure, args_hash, runner)
    
    # TODO: do we want to add a thermostat to the basement?
    if basement_thermal_zone  
        measure = ProcessHeatingandCoolingSetpoints.new
        args_hash = default_args_hash(model, measure)
        args_hash["living_thermal_zone"] = basement_thermal_zone_name
        run_measure(model, measure, args_hash, runner)
    end    

    measure = ProcessElectricBaseboard.new
    args_hash = default_args_hash(model, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    if basement_thermal_zone
	  args_hash["fbasement_thermal_zone"] = basement_thermal_zone_name
    end
    run_measure(model, measure, args_hash, runner)

    measure = ProcessCentralAirConditioner.new
    args_hash = default_args_hash(model, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    if basement_thermal_zone
	  args_hash["fbasement_thermal_zone"] = basement_thermal_zone_name
    end	
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

def get_space_types(model)

  basement_space_type = nil
  living_space_type = nil
  model.getSpaces.each do |space|
    if space.name.to_s.include? "Story 0 Space"
	  space_type = space.spaceType.get # Make a "basement" spacetype and assign it to the space with story=0
	  basement_space_type_name = "#{space_type.name.to_s}:Basement"
	  basement_space_type = space_type.clone.to_SpaceType.get
	  basement_space_type.setName(basement_space_type_name)
      space.setSpaceType(basement_space_type)
	elsif space.name.to_s.include? "Story 1 Space"
	  space_type = space.spaceType.get # Make a "living" spacetype
	  living_space_type_name = "#{space_type.name.to_s}:Living"
	  living_space_type = space_type.clone.to_SpaceType.get
	  living_space_type.setName(living_space_type_name)
	end
  end
  
  model.getSpaces.each do |space|
	next if space.name.to_s.include? "Story 0 Space"
	space.setSpaceType(living_space_type) # Assign the "living" spacetype to story!=0
  end

  return living_space_type, basement_space_type
  
end

def get_thermal_zones(model)

  basement_thermal_zone = nil
  living_thermal_zone = nil
  model.getSpaces.each do |space|
    if space.name.to_s.include? "Story 0 Space"
	  thermal_zone = space.thermalZone.get # Make a "basement" thermal zone and assign it to the space with story=0
	  basement_thermal_zone_name = "#{thermal_zone.name.to_s}:Basement"
	  basement_thermal_zone = thermal_zone.clone.to_ThermalZone.get
	  basement_thermal_zone.setName(basement_thermal_zone_name)
      space.setThermalZone(basement_thermal_zone)
	elsif space.name.to_s.include? "Story 1 Space"
	  thermal_zone = space.thermalZone.get # Make a "living" thermal zone
	  living_thermal_zone_name = "#{thermal_zone.name.to_s}:Living"
	  living_thermal_zone = thermal_zone.clone.to_ThermalZone.get
	  living_thermal_zone.setName(living_thermal_zone_name)
	end
  end
  
  model.getSpaces.each do |space|
	next if space.name.to_s.include? "Story 0 Space"
	space.setThermalZone(living_thermal_zone) # Assign the "living" thermal zone to story!=0
  end
  
  return living_thermal_zone, basement_thermal_zone
  
end

def apply_new_hvac(model, runner, heating_source, cooling_source)

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
    
    when "District Ambient Water_District Ambient Water"
    
        # [1] PLANT LOOPS
            # [1] Heat Pump Loop with:
                # [1] District Heating on Supply Side
                # [1] District Cooling on Supply Side
                # [1] Coil Heating Water To Air Heat Pump Equation Fit on Demand Side
                # [1] Coil Cooling Water To Air Heat Pump Equation Fit on Demand Side
            # [0] Hot Water Plant Loop with:
            # [0] Chilled Water Plant Loop with:
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
    
    when "Electric_District Chilled Water"
    
        # [1] PLANT LOOPS
            # [0] Hot Water Plant Loop
            # [1] Chilled Water Plant Loop with:
                # [1] District on Supply Side
                # [1] Coil Cooling Water on Demand Side
        # [1] ZONE EQUIPMENT
            # [1] Packaged Terminal Heat Pump on each zone (Living/Basement) with:
                # [1] Coil Heating DX Single Speed
                # [1] Coil Cooling Water
                # [1] Supplemental Coil Heating Electric
    
        # fan_type = "ConstantVolume" # ConstantVolume, Cycling
        # heating_type = nil
        # cooling_type = "Water" # Two Speed DX AC, Single Speed DX AC, Water
    
        # chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
        # chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
        # chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
        # chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
        # chiller_capacity_guess = nil
        
        # chilled_water_loop = model.add_chw_loop(nil,
                                                # chw_pumping_type,
                                                # chiller_cooling_type,
                                                # chiller_condenser_type,
                                                # chiller_compressor_type,
                                                # chiller_capacity_guess)
        # chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)
    
        # HelperMethods.add_pthp(model, 
                               # HelperMethods.zones_with_thermostats(model.getThermalZones),
                               # fan_type,
                               # heating_type,
                               # cooling_type,
                               # chilled_water_loop)    
    
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

    return true
    
end

def apply_residential(model, runner, heating_source, cooling_source)
  
  result = true
  
  living_space_type, basement_space_type = get_space_types(model)
  living_thermal_zone, basement_thermal_zone = get_thermal_zones(model)
 
  result = result && apply_residential_space_type(living_space_type, runner)
  result = result && apply_residential_space_type(basement_space_type, runner)
  result = result && apply_residential_characteristics(model, living_space_type, runner)
  result = result && apply_residential_constructions(model, living_space_type, basement_space_type, runner)
  result = result && apply_residential_appliances(model, living_space_type, runner)
  result = result && apply_residential_lighting(model, living_space_type, basement_space_type, runner)
  result = result && apply_residential_mels(model, living_space_type, basement_space_type, runner)
  result = result && apply_residential_hvac(model, living_space_type, living_thermal_zone, basement_thermal_zone, runner)
  # result = result && apply_residential_dhw(model, ...)
  
  model.getSpaceTypes.each do |space_type|
    if space_type.spaces.empty?
      space_type.remove
    end
  end   
  
  model.getThermalZones.each do |thermal_zone|
    if thermal_zone.spaces.empty?
      thermal_zone.remove
    end
  end  
  
  applicable = true
  if applicable
    runner.registerInfo("Removing existing HVAC and replacing with heating_source='#{heating_source}' and cooling_source='#{cooling_source}'.")
    HelperMethods.remove_existing_hvac_equipment(model, runner)
    result = result && apply_new_hvac(model, runner, heating_source, cooling_source)
  end
  
  return result
    
end

