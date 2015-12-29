def apply_residential_space_type(space_type, runner)
  
  space_type_name = space_type.name.get
  
  rendering_color = space_type.renderingColor
  if rendering_color.empty?
    rendering_color = OpenStudio::Model::RenderingColor.new(space_type.model)
    space_type.setRenderingColor(rendering_color)
  else
    rendering_color = rendering_color.get
  end
  
  case space_type_name
  when "Single-Family"
    rendering_color.setRGB(0, 0, 0)	
  when "Multifamily (2 to 4 units)"
    rendering_color.setRGB(0, 0, 0)
  when "Multifamily (5 or more units)"
    rendering_color.setRGB(0, 0, 0)
  when "Mobile Home"
    rendering_color.setRGB(0, 0, 0)         
  else
    runner.registerWarning("Unknown space use #{space_type_name}")
  end
  
  return true
end

def apply_residential_hvac(thermal_zone, runner)

  cooling_schedule = OpenStudio::Model::ScheduleConstant.new(thermal_zone.model)
  cooling_schedule.setValue(25)
  
  heating_schedule = OpenStudio::Model::ScheduleConstant.new(thermal_zone.model)
  heating_schedule.setValue(20)
  
  thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(thermal_zone.model)
  thermostat.setCoolingSetpointTemperatureSchedule(cooling_schedule)
  thermostat.setHeatingSetpointTemperatureSchedule(heating_schedule)

  thermal_zone.setThermostatSetpointDualSetpoint(thermostat)
  thermal_zone.setUseIdealAirLoads(true)
  
  return true
end

def apply_residential_constructions(model, space_type, runner)

  space_type_name = space_type.name.get

  case space_type_name
  when "Single-Family"
	
	require_relative 'beopt-measures/ProcessConstructionsExteriorInsulatedWallsWoodStud/measure.rb'
	measure = ProcessConstructionsExteriorInsulatedWallsWoodStud.new
	args_hash = default_args_hash(model, measure)
	args_hash = nondefault_args_hash(args_hash, args_hash)
	args_hash["selectedliving"] = space_type_name
	run_measure(model, measure, args_hash, runner)

	require_relative 'beopt-measures/ProcessConstructionsSlab/measure.rb'
	measure = ProcessConstructionsSlab.new
	args_hash = default_args_hash(model, measure)
	args_hash = nondefault_args_hash(args_hash, args_hash)
	args_hash["selectedliving"] = space_type_name
	run_measure(model, measure, args_hash, runner)

	require_relative 'beopt-measures/ProcessConstructionsInteriorUninsulatedWalls/measure.rb'
	measure = ProcessConstructionsInteriorUninsulatedWalls.new
	args_hash = default_args_hash(model, measure)
	args_hash = nondefault_args_hash(args_hash, args_hash)
	args_hash["selectedliving"] = space_type_name
	run_measure(model, measure, args_hash, runner)

	require_relative 'beopt-measures/ProcessConstructionsInteriorUninsulatedFloors/measure.rb'
	measure = ProcessConstructionsInteriorUninsulatedFloors.new
	args_hash = default_args_hash(model, measure)
	args_hash = nondefault_args_hash(args_hash, args_hash)
	args_hash["selectedliving"] = space_type_name
	run_measure(model, measure, args_hash, runner)

	require_relative 'beopt-measures/ProcessConstructionsInsulatedRoof/measure.rb'
	measure = ProcessConstructionsInsulatedRoof.new
	args_hash = default_args_hash(model, measure)
	args_hash = nondefault_args_hash(args_hash, args_hash)
	args_hash["selectedliving"] = space_type_name
	run_measure(model, measure, args_hash, runner)		
	
  when "Multifamily (2 to 4 units)"	
	runner.registerError("Have not defined measures and inputs for #{space_type_name}.")
	return false
  when "Multifamily (5 or more units)"
	runner.registerError("Have not defined measures and inputs for #{space_type_name}.")
	return false
  when "Mobile Home"
	runner.registerError("Have not defined measures and inputs for #{space_type_name}.")
	return false          
  else
    runner.registerWarning("Unknown space use #{space_type_name}")
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
  measure.run(model, runner, argument_map)
  result = runner.result

  if ("Success" != result.value.valueName)
    runner.registerError("Failed to run measure #{measure.name}")
    raise("Failed to run measure #{measure.name}")
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
			end
		else
			args_hash[arg.name] = nil
		end
	end
	return args_hash
end

def nondefault_args_hash(args_hash, scenario)
	# stub for modifying args_hash to a set of inputs based on the scenario
	
	args_hash = scenario
	
	return args_hash
end

def apply_residential(model, runner)
  
  result = true
  
  # modify the geometry (e.g., roof=attic) based on the building?
  
  model.getSpaceTypes.each do |space_type|
    result = result && apply_residential_space_type(space_type, runner)
	result = result && apply_residential_constructions(model, space_type, runner)
  end

  # model.getThermalZones.each do |thermal_zone|
    # result = result && apply_residential_hvac(thermal_zone, runner)
  # end
  
  return result
    
end

