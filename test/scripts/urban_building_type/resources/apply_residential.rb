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
  when "Vacant"
    rendering_color.setRGB(0, 0, 0)
  when "Office"
    rendering_color.setRGB(0, 0, 0)
  when "Laboratory"
    rendering_color.setRGB(0, 0, 0)
  when "Nonrefrigerated warehouse"
    rendering_color.setRGB(0, 0, 0)
  when "Food sales"
    rendering_color.setRGB(0, 0, 0)
  when "Public order and safety"
    rendering_color.setRGB(0, 0, 0)
  when "Outpatient health care"
    rendering_color.setRGB(0, 0, 0)
  when "Refrigerated warehouse"
    rendering_color.setRGB(0, 0, 0)
  when "Religious worship"
    rendering_color.setRGB(0, 0, 0)
  when "Public assembly"
    rendering_color.setRGB(0, 0, 0)
  when "Education"
    rendering_color.setRGB(0, 0, 0)
  when "Food service"
    rendering_color.setRGB(0, 0, 0)
  when "Inpatient health care"
    rendering_color.setRGB(0, 0, 0)
  when "Nursing"
    rendering_color.setRGB(0, 0, 0)
  when "Lodging"
    rendering_color.setRGB(0, 0, 0)
  when "Strip shopping mall"
    rendering_color.setRGB(0, 0, 0)    
  when "Enclosed mall"
    rendering_color.setRGB(0, 0, 0)
  when "Retail other than mall"
    rendering_color.setRGB(0, 0, 0)
  when "Service"
    rendering_color.setRGB(0, 0, 0)
  when "Other"
    rendering_color.setRGB(0, 0, 0)          
  else
    @runner.registerWarning("Unknown space use #{space_type_name}")
    return true
    
    #@runner.registerError("Unknown space use #{space_type_name}")
    #return false
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

def apply_residential(model, runner)
  building = model.getBuilding
  building_space_type = building.spaceType
  building_space_type_name = building_space_type.get.name.get
  
  # DLM: this measure seems to be broken
  # apply a beopt measure
  #require_relative 'beopt-measures/ModifySiteWaterMainsTemperature/measure.rb'
  #measure = ModifySiteWaterMainsTemperature.new
  #args_hash = {}
  #run_measure(model, measure, args_hash, runner)
  
  # apply another beopt measure
  require_relative 'beopt-measures/AddBuildingAmericaBenchmarkOccupants/measure.rb'
  measure = AddBuildingAmericaBenchmarkOccupants.new
  args_hash = {}
  args_hash["NumBr"] = 1
  args_hash["space_type"] = building_space_type.get.handle.to_s
  run_measure(model, measure, args_hash, runner)

  ####################################################################################################################
  # hack code to get this working
  
  result = true
  model.getSpaceTypes.each do |space_type|
    result = result && apply_residential_space_type(space_type, runner)
  end

  model.getThermalZones.each do |thermal_zone|
    result = result && apply_residential_hvac(thermal_zone, runner)
  end
    
  translator = OpenStudio::OSVersion::VersionTranslator.new
  path = OpenStudio::Path.new(File.dirname(__FILE__) + "/MinimalTemplate.osm")
  minimal_model = translator.loadModel(path).get

  space_type = minimal_model.getBuilding.spaceType.get.clone(model).to_SpaceType.get
  model.getBuilding.setSpaceType(space_type)
  
  default_construction_set = minimal_model.getBuilding.defaultConstructionSet.get.clone(model).to_DefaultConstructionSet.get
  model.getBuilding.setDefaultConstructionSet(default_construction_set)
  
  # have to assign constructions to adiabatic surfaces
  exterior_wall = default_construction_set.defaultExteriorSurfaceConstructions.get.wallConstruction.get
  interior_roof = default_construction_set.defaultInteriorSurfaceConstructions.get.roofCeilingConstruction.get
  interior_floor = default_construction_set.defaultInteriorSurfaceConstructions.get.floorConstruction.get
  model.getSurfaces.each do |surface|
    if surface.outsideBoundaryCondition == "Adiabatic"
      if surface.surfaceType == "Wall" 
        surface.setConstruction(exterior_wall)
      elsif surface.surfaceType == "RoofCeiling"
        surface.setConstruction(interior_roof)
      elsif surface.surfaceType == "Floor"
        surface.setConstruction(interior_floor)          
      end
    end
  end
  
  return result
    
end

