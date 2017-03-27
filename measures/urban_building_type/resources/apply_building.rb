  
require_relative '../resources/util'
  
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model  
  # Load the helper libraries for
  # require_relative 'Prototype.Fan'
  # require_relative 'Prototype.FanConstantVolume'
  # require_relative 'Prototype.FanVariableVolume'
  # require_relative 'Prototype.FanOnOff'
  # require_relative 'Prototype.FanZoneExhaust'
  # require_relative 'Prototype.HeatExchangerAirToAirSensibleAndLatent'
  # require_relative 'Prototype.ControllerWaterCoil'
  # require_relative 'Prototype.Model.hvac'
  # require_relative 'Prototype.Model.swh'
  # require_relative '../standards/Standards.Model'
  # require_relative 'Prototype.building_specific_methods'
  spec = Gem::Specification.find_by_name('openstudio-standards')
  gem_root = spec.gem_dir  
  require File.join(gem_root, 'lib', 'openstudio-standards', 'prototypes', 'Prototype.building_specific_methods')
    
  # Creates a DOE prototype building model and replaces
  # the current model with this model.
  #
  # @param building_type [String] the building type
  # @param template [String] the template
  # @param climate_zone [String] the climate zone
  # @param debug [Boolean] If true, will report out more detailed debugging output
  # @return [Bool] returns true if successful, false if not
  # @example Create a Small Office, 90.1-2010, in ASHRAE Climate Zone 5A (Chicago)
  #   model.create_prototype_building('SmallOffice', '90.1-2010', 'ASHRAE 169-2006-5A')

  def apply_standard(runner, building_type, template, climate_zone, heating_source, cooling_source, system_type, num_floors, floor_area, sizing_run_dir=Dir.pwd, debug=false)
    osm_file_increment = 0 
    # There are no reference models for HighriseApartment at vintages Pre-1980 and 1980-2004, nor for NECB 2011. This is a quick check.
    if building_type == 'HighriseApartment'
      if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'
        OpenStudio.logFree(OpenStudio::Error, 'Not available', "DOE Reference models for #{building_type} at template #{template} are not available, the measure is disabled for this specific type.")
        return false
      elsif template == 'NECB 2011'
        OpenStudio.logFree(OpenStudio::Error, 'Not available', "Reference model for #{building_type} at template #{template} is not available, the measure is disabled for this specific type.")
        return false
      end
    end

    lookup_building_type = get_lookup_name(building_type)

    # Retrieve the Prototype Inputs from JSON
    search_criteria = {
      'template' => template,
      'building_type' => building_type
    }

    prototype_input = find_object($os_standards['prototype_inputs'], search_criteria, nil)

    if prototype_input.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find prototype inputs for #{search_criteria}, cannot create model.")
      return false
    end    
    
    load_building_type_methods(building_type, template, climate_zone)
    # load_geometry(building_type, template, climate_zone)
    # getBuilding.setName("#{template}-#{building_type}-#{climate_zone} created: #{Time.new}")
    # space_type_map = define_space_type_map(building_type, template, climate_zone)
    # assign_space_type_stubs(lookup_building_type, template, space_type_map)
    add_loads(template, climate_zone)
    apply_infiltration_standard(template)
    modify_infiltration_coefficients(building_type, template, climate_zone)
    modify_surface_convection_algorithm(template)
    add_constructions(building_type, template, climate_zone)
    # create_thermal_zones(building_type, template, climate_zone)
    
    getSpaces.each do |space|
      zone = space.thermalZone.get

      # Skip thermostat for spaces with no space type
      next if space.spaceType.empty?

      # Add a thermostat
      space_type_name = space.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostatClone = thermostat.get.clone(self).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostatClone)
      end
    end    
    
    # add_hvac(building_type, template, climate_zone, prototype_input, epw_file)
    # custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, self)
    # add_swh(building_type, template, climate_zone, prototype_input)
    # custom_swh_tweaks(building_type, template, climate_zone, prototype_input, self)
    add_exterior_lights(building_type, template, climate_zone, prototype_input)
    add_occupancy_sensors(building_type, template, climate_zone)
    # add_design_days_and_weather_file(building_type, template, climate_zone, epw_file)
    # apply_sizing_parameters(building_type, template)
    # yearDescription.get.setDayofWeekforStartDay('Sunday')    
    
    # set climate zone and building type
    getBuilding.setStandardsBuildingType(building_type)
    if climate_zone.include? 'ASHRAE 169-2006-'
      getClimateZones.setClimateZone('ASHRAE', climate_zone.gsub('ASHRAE 169-2006-', ''))
    end
    
    # For some building types, stories are defined explicitly 
    if building_type == 'SmallHotel'
      building_story_map = PrototypeBuilding::SmallHotel.define_building_story_map(building_type, template, climate_zone)
      assign_building_story(building_type, template, climate_zone, building_story_map)
    end    
    
    # Assign building stories to spaces in the building
    # where stories are not yet assigned.
    assign_spaces_to_stories

    applicable = true
    if heating_source == "NA" and cooling_source == "NA"
      applicable = false
    else
      runner.registerInfo("Removing existing HVAC and replacing with heating_source='#{heating_source}' and cooling_source='#{cooling_source}'.")
      HelperMethods.remove_all_hvac_equipment(self, runner)
      floor_area = OpenStudio::convert(floor_area,"m^2","ft^2").get
      runner.registerInfo("Applying HVAC system with heating_source='#{heating_source}' and cooling_source='#{cooling_source}', num_floors='#{num_floors}' and floor_area='#{floor_area.round}' ft^2.")
      if system_type == "Forced air"
        result = apply_new_forced_air_system(self, runner, building_type, template, heating_source, cooling_source, num_floors, floor_area)
      elsif system_type == "Hydronic"
        result = apply_new_hydronic_system(self, runner, building_type, template, heating_source, cooling_source, num_floors, floor_area)
      else
        runner.registerInfo("Did not select either 'Forced air' or 'Hydronic' system type.")
      end
      return false if !result
    end  

    # Perform a sizing run
    if runSizingRun("#{sizing_run_dir}/SR1") == false
      return false
    end
    
    # If there are any multizone systems, reset damper positions
    # to achieve a 60% ventilation effectiveness minimum for the system
    # following the ventilation rate procedure from 62.1
    apply_multizone_vav_outdoor_air_sizing(template)    
    
    # Apply the prototype HVAC assumptions
    # which include sizing the fan pressure rises based
    # on the flow rate of the system.
    apply_prototype_hvac_assumptions(building_type, template, climate_zone)    

    # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
    # AHU1 doesn't have economizer
    # if building_type == 'Outpatient' TODO: delete these
      # PrototypeBuilding::Outpatient.modify_oa_controller(template, self)
      # # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
      # PrototypeBuilding::Outpatient.reset_or_room_vav_minimum_damper(prototype_input, template, self)
    # end

    # if building_type == 'Hospital'
      # PrototypeBuilding::Hospital.modify_hospital_oa_controller(template, self)
    # end

    # Apply the HVAC efficiency standard
    apply_hvac_efficiency_standard(template, climate_zone)
    
    # Add daylighting controls per standard
    # only four zones in large hotel have daylighting controls
    # todo: YXC to merge to the main function
    # if building_type == 'LargeHotel'
      # # PrototypeBuilding::LargeHotel.large_hotel_add_daylighting_controls(template, self)
    # elsif building_type == 'Hospital'
      # # PrototypeBuilding::Hospital.hospital_add_daylighting_controls(template, self)
    # else
    add_daylighting_controls(template)
    # end

    # if building_type == 'QuickServiceRestaurant'
      # PrototypeBuilding::QuickServiceRestaurant.update_exhaust_fan_efficiency(template, self)
    # elsif building_type == 'FullServiceRestaurant'
      # PrototypeBuilding::FullServiceRestaurant.update_exhaust_fan_efficiency(template, self)
    # elsif building_type == 'Outpatient'
      # PrototypeBuilding::Outpatient.update_exhaust_fan_efficiency(template, self)
    # end

    # if building_type == 'HighriseApartment'
      # PrototypeBuilding::HighriseApartment.update_fan_efficiency(self)
    # end

    # Add output variables for debugging
    if debug
      request_timeseries_outputs
    end

    # Finished
    model_status = 'final'
    save(OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.osm"), true)

    return true    
  end  
   
end
  
def apply_new_forced_air_system(model, runner, building_type, building_vintage, heating_source, cooling_source, num_floors, floor_area)

    search_criteria = {
      'template' => building_vintage,
      'building_type' => building_type
    }
    prototype_input = model.find_object($os_standards['prototype_inputs'], search_criteria)
    
    if [["District Ambient Water", "Electric"], ["District Ambient Water", "District Chilled Water"], ["Gas", "District Ambient Water"], ["Electric", "District Ambient Water"], ["District Hot Water", "District Ambient Water"]].include? [heating_source, cooling_source]
      runner.registerError("Heating source '#{heating_source}' and cooling source '#{cooling_source}' not supported.")
      return false
    end
    
    main_heat_fuel_map = {"Gas"=>"NaturalGas", "Electric"=>"Electricity", "District Hot Water"=>"DistrictHeating", "District Ambient Water"=>"AmbientWater"}
    cool_fuel_map = {"Electric"=>"Electricity", "District Chilled Water"=>"DistrictCooling", "District Ambient Water"=>"AmbientWater"}
    
    system_type = nil
    main_heat_fuel = main_heat_fuel_map[heating_source]
    cool_fuel = cool_fuel_map[cooling_source]
    zones = HelperMethods.zones_with_thermostats(model.getThermalZones)
    zone_heat_fuel = nil

    case building_type
    when "MidriseApartment", "HighriseApartment" # Residential
    
      if num_floors < 3 # Single-Family, MidriseApartment
      
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type = "PTAC"
          elsif cool_fuel == "DistrictCooling"
            system_type = "DOAS"
          end
        elsif main_heat_fuel == "Electricity"
          if cool_fuel == "Electricity"
            system_type = "PTHP"
          elsif cool_fuel == "DistrictCooling"
            system_type == "PSZ_AC"
          end
        elsif main_heat_fuel == "AmbientWater"
          system_type = "Zone Water-to-Air HP w/ERV"
        end
        
      else # HighriseApartment
      
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type = "PTAC"
          elsif cool_fuel == "DistrictCooling"
            system_type = "DOAS"
          end
        elsif main_heat_fuel == "Electricity"
          if cool_fuel == "Electricity"
            system_type = "PTHP"
          elsif cool_fuel == "DistrictCooling"
            system_type = "PSZ_AC"
          end
        elsif main_heat_fuel == "AmbientWater"
          system_type = "Zone Water-to-Air HP w/DOAS"
        end      
      
      end
    
    else # Commercial
    
      if num_floors < 3 or floor_area < 75000 # Small
    
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type =  "PSZ_AC"
          elsif cool_fuel == "DistrictCooling"
            system_type = "PSZ_AC"
          end
        elsif main_heat_fuel == "Electric"
          if cool_fuel == "Electricity"
            system_type = "PSZ_HP"
          elsif cool_fuel == "DistrictCooling"
            system_type = "PSZ_HP"
          end            
        elsif main_heat_fuel == "AmbientWater"
          system_type = "Zone Water-to-Air HP w/DOAS"
        end
  
      elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000) # Medium
        
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type =  "PVAV_Reheat"
          elsif cool_fuel == "DistrictCooling"
            system_type = "VAV_Reheat"
          end            
        elsif main_heat_fuel == "Electric"
          if cool_fuel == "Electricity"
            system_type = "PVAV_PFP_Boxes"
          elsif cool_fuel == "DistrictCooling"
            system_type = "PVAV_PFP_Boxes"
          end          
        elsif main_heat_fuel == "AmbientWater"
          system_type = "VAV w/Heat Pumps"
        end
        
      elsif num_floors > 5 or floor_area > 150000 # Large
        
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type =  "VAV_Reheat"
          elsif cool_fuel == "DistrictCooling"
            system_type = "VAV_Reheat"
          end
        elsif main_heat_fuel == "Electric"
          if cool_fuel == "Electricity"
            system_type = "VAV_PFP_Boxes"
          elsif cool_fuel == "DistrictCooling"
            system_type = "VAV_PFP_Boxes"
          end
        elsif main_heat_fuel == "AmbientWater"
          system_type = "VAV w/Heat Pumps"
        end

      end
        
    end

    add_system(building_vintage, system_type, main_heat_fuel, zone_heat_fuel, cool_fuel, zones)

    puts "Forced air system '#{system_type}' applied to #{building_type}."
      
    return true
    
end

def apply_new_hydronic_system(model, runner, building_type, building_vintage, heating_source, cooling_source, num_floors, floor_area)

    search_criteria = {
      'template' => building_vintage,
      'building_type' => building_type
    }
    prototype_input = model.find_object($os_standards['prototype_inputs'], search_criteria)
    
    if [["District Ambient Water", "Electric"], ["District Ambient Water", "District Chilled Water"], ["Gas", "District Ambient Water"], ["Electric", "District Ambient Water"], ["District Hot Water", "District Ambient Water"]].include? [heating_source, cooling_source]
      runner.registerError("Heating source '#{heating_source}' and cooling source '#{cooling_source}' not supported.")
      return false
    end
    
    main_heat_fuel_map = {"Gas"=>"NaturalGas", "Electric"=>"Electricity", "District Hot Water"=>"DistrictHeating", "District Ambient Water"=>"AmbientWater"}
    cool_fuel_map = {"Electric"=>"Electricity", "District Chilled Water"=>"DistrictCooling", "District Ambient Water"=>"AmbientWater"}
    
    system_type = nil
    main_heat_fuel = main_heat_fuel_map[heating_source]
    cool_fuel = cool_fuel_map[cooling_source]
    zones = HelperMethods.zones_with_thermostats(model.getThermalZones)
    zone_heat_fuel = nil

    case building_type
    when "MidriseApartment", "HighriseApartment" # Residential
    
      if num_floors < 3 # Single-Family, MidriseApartment
      
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type = "PTAC"
          elsif cool_fuel == "DistrictCooling"
            system_type = "DOAS"
          end
        elsif main_heat_fuel == "Electricity"
          if cool_fuel == "Electricity"
            system_type = "PTHP"
          elsif cool_fuel == "DistrictCooling"
            system_type == "PSZ_AC"
          end
        elsif main_heat_fuel == "AmbientWater"
          system_type = "Zone Water-to-Air HP w/ERV"
        end
        
      else # HighriseApartment
      
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type = "PTAC"
          elsif cool_fuel == "DistrictCooling"
            system_type = "DOAS"
          end
        elsif main_heat_fuel == "Electricity"
          if cool_fuel == "Electricity"
            system_type = "PTHP"
          elsif cool_fuel == "DistrictCooling"
            system_type = "PSZ_AC"
          end
        elsif main_heat_fuel == "AmbientWater"
          system_type = "Zone Water-to-Air HP w/DOAS"
        end      
      
      end
    
    else # Commercial
    
      if num_floors < 3 or floor_area < 75000 # Small
    
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type =  "PSZ_AC"
          elsif cool_fuel == "DistrictCooling"
            system_type = "PSZ_AC"
          end
        elsif main_heat_fuel == "Electric"
          if cool_fuel == "Electricity"
            system_type = "PSZ_HP"
          elsif cool_fuel == "DistrictCooling"
            system_type = "PSZ_HP"
          end            
        elsif main_heat_fuel == "AmbientWater"
          system_type = "Zone Water-to-Air HP w/DOAS"
        end
  
      elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000) # Medium
        
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type =  "PVAV_Reheat"
          elsif cool_fuel == "DistrictCooling"
            system_type = "VAV_Reheat"
          end            
        elsif main_heat_fuel == "Electric"
          if cool_fuel == "Electricity"
            system_type = "PVAV_PFP_Boxes"
          elsif cool_fuel == "DistrictCooling"
            system_type = "PVAV_PFP_Boxes"
          end          
        elsif main_heat_fuel == "AmbientWater"
          system_type = "Zone Water-to-Air HP w/DOAS"
        end
        
      elsif num_floors > 5 or floor_area > 150000 # Large
        
        if main_heat_fuel == "NaturalGas" or main_heat_fuel == "DistrictHeating"
          if cool_fuel == "Electricity"
            system_type =  "VAV_Reheat"
          elsif cool_fuel == "DistrictCooling"
            system_type = "VAV_Reheat"
          end
        elsif main_heat_fuel == "Electric"
          if cool_fuel == "Electricity"
            system_type = "VAV_PFP_Boxes"
          elsif cool_fuel == "DistrictCooling"
            system_type = "VAV_PFP_Boxes"
          end
        elsif main_heat_fuel == "AmbientWater"
          system_type = "VAV w/Heat Pumps"
        end

      end
        
    end
    
    add_system(building_vintage, system_type, main_heat_fuel, zone_heat_fuel, cool_fuel, zones)

    puts "Hydronic system '#{system_type}' applied to #{building_type}."
      
    return true
    
end

# returns "Large", "Medium", or "Small"
def office_size(floor_area, runner)
  result = "Medium"
      
  # todo: put in real ranges
  if floor_area > 40000
    result = "Large"
  elsif floor_area > 4000
    result = "Medium"
  elsif floor_area > 0
    result = "Small"
  else
    runner.registerError("Building floor area is 0, cannot determine office size")
  end
  
  return result
end

def hotel_size(floor_area, runner)
  result = "Large"
      
  # todo: put in real ranges
  if floor_area > 10000
    result = "Large"
  elsif floor_area > 0
    result = "Small"
  else
    runner.registerError("Building floor area is 0, cannot determine hotel size")
  end
  
  return result
end

def restaurant_size(floor_area, runner)
  result = "Full"
      
  # todo: put in real ranges
  if floor_area > 500
    result = "Full"
  elsif floor_area > 0
    result = "Quick"
  else
    runner.registerError("Building floor area is 0, cannot determine restaurant size")
  end
  
  return result
end

def school_size(floor_area, runner)
  result = "Secondary"
      
  # todo: put in real ranges
  if floor_area > 15000
    result = "Secondary"
  elsif floor_area > 0
    result = "Primary"
  else
    runner.registerError("Building floor area is 0, cannot determine school size")
  end
  
  return result
end

# map the cbecs space type to a prototype building
def prototype_building_type(model, runner)

  building = model.getBuilding
  building_space_type = building.spaceType
  standards_building_type = building_space_type.get.standardsBuildingType.get

  building_type = nil
  num_floors = model.getBuildingStorys.length
  floor_area = model.getBuilding.floorArea
  
  case standards_building_type
  when "Vacant"
    # DLM: temporary
    building_type = 'Warehouse'
  when "Office"
    size = office_size(floor_area, runner)
    if size == 'Large'
      building_type = 'LargeOffice'
    elsif size == 'Medium'
      building_type = 'MediumOffice'
    elsif size == 'Small'
      building_type = 'SmallOffice'
    end
  when "Laboratory"
    runner.registerError("Have not defined measures and inputs for #{standards_building_type}.")
    return false, building_type, num_floors, floor_area
  when "Nonrefrigerated warehouse"
    building_type = 'Warehouse'
  when "Food sales"
    building_type = 'RetailStandalone'
  when "Public order and safety"
    runner.registerError("Have not defined measures and inputs for #{standards_building_type}.")
    return false, building_type, num_floors, floor_area
  when "Outpatient health care"
    building_type = 'Outpatient'
  when "Refrigerated warehouse"
    building_type = 'Warehouse'
  when "Religious worship"
    runner.registerError("Have not defined measures and inputs for #{standards_building_type}.")
    return false, building_type, num_floors, floor_area
  when "Public assembly"
    runner.registerError("Have not defined measures and inputs for #{standards_building_type}.")
    return false, building_type, num_floors, floor_area
  when "Education"
    size = school_size(floor_area, runner)
    if size == 'Primary'
      building_type = 'PrimarySchool'
    elsif size == 'Secondary'
      building_type = 'SecondarySchool'
    end
  when "Food service"
    size = restaurant_size(floor_area, runner)
    if size == 'Full'
      building_type = 'FullServiceRestaurant'
    elsif size == 'Quick'
      building_type = 'QuickServiceRestaurant'
    end
  when "Inpatient health care"
    building_type = 'Hospital'
  when "Nursing"
    building_type = 'Outpatient'
  when "Lodging"
    size = hotel_size(floor_area, runner)
    if size == 'Large'
      building_type = 'LargeHotel'
    elsif size == 'Small'
      building_type = 'SmallHotel'
    end
  when "Strip shopping mall"
    building_type = 'RetailStripmall'
  when "Enclosed mall"
    building_type = 'RetailStandalone'
  when "Retail other than mall"
    building_type = 'RetailStandalone'
  when "Service"
    building_type = 'RetailStripmall'
  when "Single-Family"
    building_type = 'MidriseApartment'
  when "Multifamily (2 to 4 units)"
    building_type = 'MidriseApartment'
  when "Multifamily (5 or more units)"
    building_type = 'HighriseApartment'
  when "Other"
    runner.registerError("Have not defined measures and inputs for #{standards_building_type}.")
    return false, building_type, num_floors, floor_area
  else
    runner.registerError("Have not defined measures and inputs for #{standards_building_type}.")
    return false, building_type, num_floors, floor_area
  end
  
  return true, building_type, num_floors, floor_area

end

# map the cbecs space type to standards space type
def map_space_type(space_type, runner)
  
  standards_building_type = space_type.standardsBuildingType.get
  standards_space_type = space_type.standardsSpaceType.get
  
  new_building_type = standards_building_type
  new_space_type = standards_space_type

  floor_area = space_type.model.getBuilding.floorArea
  case standards_building_type
  when "Vacant"
    # DLM: temp
    new_space_type = 'Bulk'
    new_building_type = 'Warehouse'
  when "Office"
    size = office_size(floor_area, runner)
    if size == 'Large'
      new_space_type = 'WholeBuilding - Lg Office'
    elsif size == 'Medium'
      new_space_type = 'WholeBuilding - Md Office'
    elsif size == 'Small'
      new_space_type = 'WholeBuilding - Sm Office'
    end
  when "Nonrefrigerated warehouse"
    new_space_type = 'Bulk'
    new_building_type = 'Warehouse'
  when "Food sales"
    new_space_type = 'Retail'
    new_building_type = 'Retail'
  when "Outpatient health care"
    new_space_type = 'Exam'
    new_building_type = 'Outpatient'
  when "Refrigerated warehouse"
    new_space_type = 'Bulk'
    new_building_type = 'Warehouse'
  when "Education"
    new_space_type = 'Classroom'
    size = school_size(floor_area, runner)
    if size == 'Primary'
      new_building_type = 'PrimarySchool'
    elsif size == 'Secondary'
      new_building_type = 'SecondarySchool'
    end    
  when "Food service"
    new_space_type = 'Dining'
    size = restaurant_size(floor_area, runner)
    if size == 'Full'
      new_building_type = 'FullServiceRestaurant'
    elsif size == 'Quick'
      new_building_type = 'QuickServiceRestaurant'
    end
  when "Inpatient health care"
    new_space_type = 'PatRoom'
    new_building_type = 'Hospital'
  when "Nursing"
    new_space_type = 'Exam'
    new_building_type = 'Outpatient'
  when "Lodging"
    size = hotel_size(floor_area, runner)
    if size == 'Large'
      new_space_type = 'GuestRoom'
      new_building_type = 'LargeHotel'
    elsif size == 'Small'
      new_space_type = 'GuestRoom123Occ'
      new_building_type = 'SmallHotel'
    end    
  when "Strip shopping mall"
    new_space_type = 'Strip mall - type 1'
    new_building_type = 'StripMall'
  when "Enclosed mall"
    new_space_type = 'Retail'
    new_building_type = 'Retail'
  when "Retail other than mall"
    new_space_type = 'Retail'
    new_building_type = 'Retail'
  when "Service"
    new_space_type = 'Strip mall - type 1'
    new_building_type = 'StripMall'
  when "Single-Family"
    building_type = 'Apartment'
  when "Multifamily (2 to 4 units)"
    building_type = 'Apartment'
  when "Multifamily (5 or more units)"
    building_type = 'Apartment'  
  else
    runner.registerError("Unknown building type #{standards_building_type}")
  end
  
  space_type.setStandardsBuildingType(new_building_type)
  space_type.setStandardsSpaceType(new_space_type)

end

def apply_building(model, runner, heating_source, cooling_source, system_type)

  num_spaces = model.getSpaces.length.to_i

  result, building_type, num_floors, floor_area = prototype_building_type(model, runner)
  building_vintage = "90.1-2010"
  climate_zone = nil
  model.getClimateZones.climateZones.each do |cz|
    next unless cz.institution == "ASHRAE"
    climate_zone = "ASHRAE 169-2006-#{cz.value}"
  end
  
  if !result
    runner.registerError("Cannot apply building type")
    return result
  end  
    
  model.getSpaceTypes.each do |space_type|
    map_space_type(space_type, runner)
  end
  
  result = model.apply_standard(runner, building_type, building_vintage, climate_zone, heating_source, cooling_source, system_type, num_floors, floor_area)
  
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
  
  runner.registerValue('bldg_use', building_type)
  runner.registerValue('num_spaces', num_spaces, 'spaces')
  
  return result
    
end

