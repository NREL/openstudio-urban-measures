# similar to code in openstudio-standards Prototype.Model.rb
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {}
    
    self.getSpaceTypes.each do |space_type|
      standards_space_type = space_type.standardsSpaceType.get
      space_names = []
      space_type.spaces.each do |space|
        space_names << space.name.to_s
      end
      space_type_map[standards_space_type] = space_names
    end
    
    return space_type_map
  end
  
  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    
    system_to_space_map = []
    
    self.getBuildingStorys.each do |building_story|
    
      space_names = []
      building_story.spaces.each do |space|
        space_names << space.name.to_s
      end
      
      system_to_space_map << {'type' => 'VAV', 'name' => "VAV #{building_story.name}", 'space_names' => space_names}
     
    end
    
    return system_to_space_map
  end
  
  # would be good if this was in the main code
  def add_hvac(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
  
    # TODO: fix this
    self.getThermalZones.each do |thermal_zone|
      cooling_schedule = OpenStudio::Model::ScheduleConstant.new(thermal_zone.model)
      cooling_schedule.setValue(25)
      
      heating_schedule = OpenStudio::Model::ScheduleConstant.new(thermal_zone.model)
      heating_schedule.setValue(20)
      
      thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(thermal_zone.model)
      thermostat.setCoolingSetpointTemperatureSchedule(cooling_schedule)
      thermostat.setHeatingSetpointTemperatureSchedule(heating_schedule)

      thermal_zone.setThermostatSetpointDualSetpoint(thermostat)
      thermal_zone.setUseIdealAirLoads(true)
    end
    
    return true
  end
  
  # would be good if this was in the main code
  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
    # TODO: fix this
    return true
  end
  
  # Creates a DOE prototype building model and replaces
  # the current model with this model.
  #
  # @param building_type [String] the building type
  # @param building_vintage [String] the building vintage
  # @param climate_zone [String] the climate zone  
  # @param debug [Boolean] If true, will report out more detailed debugging output
  # @return [Bool] returns true if successful, false if not
  # @example Create a Small Office, 90.1-2010, in ASHRAE Climate Zone 5A (Chicago)
  #   model.create_prototype_building('SmallOffice', '90.1-2010', 'ASHRAE 169-2006-5A')
  def apply_standard(runner, building_type, building_vintage, climate_zone, sizing_run_dir = Dir.pwd, debug = false)  

    logStream = OpenStudio::StringStreamLogSink.new
    logStream.setLogLevel(OpenStudio::Warn)
    
    begin
runner.registerInfo( "1" )
      self.load_openstudio_standards_json
      lookup_building_type = self.get_lookup_name(building_type)
      
      # Assign the standards to the model
      self.template = building_vintage
      self.climate_zone = climate_zone    
      
      # Retrieve the Prototype Inputs from JSON
      search_criteria = {
        'template' => building_vintage,
        'building_type' => building_type
      }
      prototype_input = self.find_object(self.standards['prototype_inputs'], search_criteria)
      if prototype_input.nil?
        runner.registerError("Could not find prototype inputs for #{search_criteria}, cannot create model.")
        return false
      end
runner.registerInfo( "2" )
      #self.load_building_type_methods(building_type, building_vintage, climate_zone)
      #self.load_geometry(building_type, building_vintage, climate_zone)
      #self.getBuilding.setName("#{building_vintage}-#{building_type}-#{climate_zone} created: #{Time.new}")
      space_type_map = self.define_space_type_map(building_type, building_vintage, climate_zone)
runner.registerInfo( "2a" )
      runner.registerInfo( "Before: #{self.getSpaceTypes.size}" )
      self.assign_space_type_stubs(lookup_building_type, space_type_map)
      runner.registerInfo( "After: #{self.getSpaceTypes.size}" )
runner.registerInfo( "3" )
      
      self.add_loads(building_vintage, climate_zone)
      self.apply_infiltration_standard
      self.modify_infiltration_coefficients(building_type, building_vintage, climate_zone)
      self.modify_surface_convection_algorithm(building_vintage)
      self.add_constructions(lookup_building_type, building_vintage, climate_zone)
      self.create_thermal_zones(building_type,building_vintage, climate_zone)
      self.add_hvac(building_type, building_vintage, climate_zone, prototype_input, self.standards)
      self.add_swh(building_type, building_vintage, climate_zone, prototype_input, self.standards, space_type_map)
      self.add_exterior_lights(building_type, building_vintage, climate_zone, prototype_input)
      self.add_occupancy_sensors(building_type, building_vintage, climate_zone)
      self.add_design_days_and_weather_file(self.standards, building_type, building_vintage, climate_zone)
      self.set_sizing_parameters(building_type, building_vintage)
      self.yearDescription.get.setDayofWeekforStartDay('Sunday')
runner.registerInfo( "4" )
      # Perform a sizing run
      if self.runSizingRun("#{sizing_run_dir}/SizingRun1") == false
        return false
      end
runner.registerInfo( "5" )
      # If there are any multizone systems, set damper positions
      # and perform a second sizing run
      has_multizone_systems = false
      self.getAirLoopHVACs.sort.each do |air_loop|
        if air_loop.is_multizone_vav_system
          self.apply_multizone_vav_outdoor_air_sizing
          if self.runSizingRun("#{sizing_run_dir}/SizingRun2") == false
            return false
          end
          break
        end
      end
runner.registerInfo( "6" )
      # Apply the prototype HVAC assumptions
      # which include sizing the fan pressure rises based
      # on the flow rate of the system.
      self.applyPrototypeHVACAssumptions(building_type, building_vintage, climate_zone)
runner.registerInfo( "7" )
      # Apply the HVAC efficiency standard
      self.applyHVACEfficiencyStandard
runner.registerInfo( "8" )
      # Add daylighting controls per standard
      # only four zones in large hotel have daylighting controls
      # todo: YXC to merge to the main function
      if building_type != "LargeHotel"
        self.addDaylightingControls
      else
        self.add_daylighting_controls(building_vintage)
      end
runner.registerInfo( "9" )
      if building_type == "QuickServiceRestaurant" || building_type == "FullServiceRestaurant"
        self.update_exhaust_fan_efficiency(building_vintage)
        self.update_waterheater_loss_coefficient(building_vintage)
      end
      
      if building_type == "MidriseApartment"
        self.update_waterheater_loss_coefficient(building_vintage)
      end
     
      # Add output variables for debugging
      if debug
        self.request_timeseries_outputs
      end
runner.registerInfo( "10" )
    rescue Exception => e  
    
      runner.registerError("#{e}")
      
      # print log messages
      logStream.logMessages.each do |logMessage|
        if logMessage.logLevel < OpenStudio::Warn
          runner.registerInfo(logMessage.logMessage)
        elsif logMessage.logLevel == OpenStudio::Warn
          runner.registerWarning(logMessage.logMessage)
        else
          runner.registerError(logMessage.logMessage)
        end
      end
      return false
      
    end
   
    return true    
  end
  
end

# returns "Large", "Medium", or "Small"
def office_size(model, runner)
  result = "Large"
  
  floor_area = model.getBuilding.floorArea
    
  # todo: put in real ranges
  if floor_area > 2
    result = "Large"
  elsif floor_area > 1
    result = "Medium"
  elsif floor_area > 0
    result = "Small"
  else
    runner.registerError("Building floor area is 0, cannot determine office size")
  end
  
  return result
end

# map the cbecs space type to a prototype building
def prototype_building_type(model, runner)

  building = model.getBuilding
  building_space_type = building.spaceType
  standards_building_type = building_space_type.get.standardsBuildingType.get

  result = nil
  case standards_building_type
  when "Single-Family"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Multifamily (2 to 4 units)"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Multifamily (5 or more units)"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Mobile Home"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Vacant"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Office"

    size = office_size(model, runner)
    if size == 'Large'
      result = 'LargeOffice'
    elsif size == 'Medium'
      result = 'MediumOffice'
    elsif size == 'Small'
      result = 'SmallOffice'
    end
    
  when "Laboratory"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Nonrefrigerated warehouse"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Food sales"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Public order and safety"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Outpatient health care"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Refrigerated warehouse"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Religious worship"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Public assembly"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Education"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Food service"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Inpatient health care"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Nursing"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Lodging"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Strip shopping mall"
    runner.registerError("#{standards_building_type} is not a commercial building type")   
  when "Enclosed mall"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Retail other than mall"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Service"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Other"
    runner.registerError("#{standards_building_type} is not a commercial building type")      
  else
    runner.registerError("Unknown building type #{standards_building_type}")
  end
  
  return result

end

# map the cbecs space type to standards space type
def map_space_type(space_type, runner)
  
  standards_building_type = space_type.standardsBuildingType.get
  standards_space_type = space_type.standardsSpaceType
  
  new_building_type = standards_building_type
  new_space_type = standards_space_type

  case standards_building_type
  when "Single-Family"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Multifamily (2 to 4 units)"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Multifamily (5 or more units)"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Mobile Home"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Vacant"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Office"
    new_building_type = 'Office' 
    
    size = office_size(space_type.model, runner)
    if size == "Large"
      new_space_type = 'WholeBuilding - Lg Office'
    elsif size == "Medium"
      new_space_type = 'WholeBuilding - Md Office'
    elsif size == "Small"
      new_space_type = 'WholeBuilding - Sm Office'
    end
    
  when "Laboratory"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Nonrefrigerated warehouse"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Food sales"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Public order and safety"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Outpatient health care"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Refrigerated warehouse"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Religious worship"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Public assembly"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Education"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Food service"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Inpatient health care"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Nursing"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Lodging"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Strip shopping mall"
    runner.registerError("#{standards_building_type} is not a commercial building type")   
  when "Enclosed mall"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Retail other than mall"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Service"
    runner.registerError("#{standards_building_type} is not a commercial building type")
  when "Other"
    runner.registerError("#{standards_building_type} is not a commercial building type")      
  else
    runner.registerError("Unknown building type #{standards_building_type}")
  end
  
  space_type.setStandardsBuildingType(new_building_type)
  space_type.setStandardsSpaceType(new_space_type)

end

def apply_commercial(model, runner)

  building_type = prototype_building_type(model, runner)
  
  model.getSpaceTypes.each do |space_type|
    map_space_type(space_type, runner)
  end
  
  result = model.apply_standard(runner, building_type, '90.1-2010', 'ASHRAE 169-2006-5A')
  if !result
    runner.registerError("Cannot apply building type")
    return result
  end
  
  model.getThermalZones.each do |thermal_zone|
    if thermal_zone.spaces.empty?
      thermal_zone.remove
    end
  end
  
  default_construction_set = model.getBuilding.defaultConstructionSet
  if !default_construction_set.empty?
    default_construction_set = default_construction_set.get
    
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
  end
  
  return result
    
end

