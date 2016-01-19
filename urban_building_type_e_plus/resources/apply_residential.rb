def apply_residential_infil(workspace, standards_space_type, living_thermal_zone, basement_thermal_zone, runner)

  runner.registerInfo("Applying residential infiltration.")  
  require './resources/measures/ProcessAirflow/measure.rb'
  
  case standards_space_type
  when "Single-Family"	
	
	measure = ProcessAirflow.new
	args_hash = default_args_hash(workspace, measure)
	args_hash["living_thermal_zone"] = living_thermal_zone
	unless basement_thermal_zone.nil?
	  args_hash["fbasement_thermal_zone"] = basement_thermal_zone
	end
	run_measure(workspace, measure, args_hash, runner)
	
  when "Multifamily (2 to 4 units)"	

	measure = ProcessAirflow.new
	args_hash = default_args_hash(workspace, measure)
	args_hash["living_thermal_zone"] = living_thermal_zone
	unless basement_thermal_zone.nil?
	  args_hash["fbasement_thermal_zone"] = basement_thermal_zone
	end
	run_measure(workspace, measure, args_hash, runner)
  
  when "Multifamily (5 or more units)"

	measure = ProcessAirflow.new
	args_hash = default_args_hash(workspace, measure)
	args_hash["living_thermal_zone"] = living_thermal_zone
	unless basement_thermal_zone.nil?
	  args_hash["fbasement_thermal_zone"] = basement_thermal_zone
	end	
	run_measure(workspace, measure, args_hash, runner)
  
  when "Mobile Home"
	runner.registerError("Have not defined measures and inputs for #{standards_space_type}.")
	return false          
  else
    runner.registerWarning("Unknown standards space type '#{standards_space_type}'.")
  end
  
  return true	
	
end

def run_measure(workspace, measure, args_hash, runner)
  # get arguments
  arguments = measure.arguments(workspace)
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
  test = measure.run(workspace, runner, argument_map)

  if !test
    runner.registerError("Failed to run measure #{measure.name}")
  end
end

def default_args_hash(workspace, measure)
	args_hash = {}
	arguments = measure.arguments(workspace)
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

def get_thermal_zones(workspace)

  basement_thermal_zone = nil
  living_thermal_zone = nil
  workspace.getObjectsByType("Zone".to_IddObjectType).each do |zone|
    if zone.getString(0).to_s.include? "Living"
	  living_thermal_zone = zone.getString(0).to_s
	elsif zone.getString(0).to_s.include? "Basement"
	  basement_thermal_zone = zone.getString(0).to_s	
	end
  end

  return living_thermal_zone, basement_thermal_zone
  
end

def apply_residential(workspace, runner, standards_space_type)
  
  result = true
  
  living_thermal_zone, basement_thermal_zone = get_thermal_zones(workspace)
 
  result = result && apply_residential_infil(workspace, standards_space_type, living_thermal_zone, basement_thermal_zone, runner)
  
  return result
    
end

