require_relative '../resources/geometry'

def apply_residential_infil(workspace, standards_space_type, control_zone, slave_zones, runner)

  runner.registerInfo("Applying residential infiltration.")  
  require './resources/measures/ProcessAirflow/measure.rb'
  
  living_thermal_zone_name = control_zone.name.get
  fbasement_thermal_zone_name = nil
  unless slave_zones.empty?
    fbasement_thermal_zone_name = slave_zones[0].name.get
  end
  
  case standards_space_type
  when "Single-Family"	
    
    measure = ProcessAirflow.new
    args_hash = default_args_hash(workspace, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    unless fbasement_thermal_zone_name.nil?
      args_hash["fbasement_thermal_zone"] = fbasement_thermal_zone_name
    end
    run_measure(workspace, measure, args_hash, runner)
	
  when "Multifamily (2 to 4 units)"	

    measure = ProcessAirflow.new
    args_hash = default_args_hash(workspace, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
    run_measure(workspace, measure, args_hash, runner)
  
  when "Multifamily (5 or more units)"

    measure = ProcessAirflow.new
    args_hash = default_args_hash(workspace, measure)
    args_hash["living_thermal_zone"] = living_thermal_zone_name
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
  puts 'here0'
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
    puts 'here1'
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

def apply_residential_e_plus(workspace, runner, standards_building_type, model)
  
  result = true

  control_slave_zones_hash = Geometry.get_control_and_slave_zones(model)
 
  all_slave_zones = []
  control_slave_zones_hash.each do |control_zone, slave_zones|
    result = result && apply_residential_infil(workspace, standards_building_type, control_zone, slave_zones, runner)
    unless slave_zones.empty?
      all_slave_zones += slave_zones
    end    
  end
  puts "#{standards_building_type} has #{control_slave_zones_hash.keys.length} control zone(s) and #{all_slave_zones.length} slave zone(s)." 
  puts result
  return result
    
end
