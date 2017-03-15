  
require_relative '../resources/util'
  
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model  
  
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
  def apply_standard(runner, building_type, building_vintage, climate_zone, heating_source, cooling_source, num_floors, floor_area, sizing_run_dir=Dir.pwd, debug=false)
    
    # There are no reference models for HighriseApartment at vintages Pre-1980 and 1980-2004. This is a quick check.
    if building_type == "HighriseApartment"
      if building_vintage == 'DOE Ref Pre-1980' or building_vintage == 'DOE Ref 1980-2004'
        OpenStudio::logFree(OpenStudio::Error, 'Not available', "DOE Reference models for #{building_type} at vintage #{building_vintage} are not available, the measure is disabled for this specific type.")
        return false
      end
    end

    lookup_building_type = self.get_lookup_name(building_type)

    # Retrieve the Prototype Inputs from JSON
    search_criteria = {
      'template' => building_vintage,
      'building_type' => building_type
    }
    prototype_input = self.find_object($os_standards['prototype_inputs'], search_criteria)
    if prototype_input.nil?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find prototype inputs for #{search_criteria}, cannot create model.")
      return false
    end

    # self.load_building_type_methods(building_type, building_vintage, climate_zone)
    # self.load_geometry(building_type, building_vintage, climate_zone)
    # self.getBuilding.setName("#{building_vintage}-#{building_type}-#{climate_zone} created: #{Time.new}")
    # space_type_map = self.define_space_type_map(building_type, building_vintage, climate_zone)
    # self.assign_space_type_stubs(lookup_building_type, building_vintage, space_type_map)
    self.add_loads(building_vintage, climate_zone)
    self.apply_infiltration_standard(building_vintage)
    self.modify_infiltration_coefficients(building_type, building_vintage, climate_zone)
    self.modify_surface_convection_algorithm(building_vintage)
    self.add_constructions(lookup_building_type, building_vintage, climate_zone)
    # self.create_thermal_zones(building_type, building_vintage, climate_zone)
    self.getSpaces.each do |space|
      zone = space.thermalZone.get

      # Skip thermostat for spaces with no space type
      next if space.spaceType.empty?

      # Add a thermostat
      space_type_name = space.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = self.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostatClone = thermostat.get.clone(self).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostatClone)
      end
    end      
    # self.add_hvac(building_type, building_vintage, climate_zone, prototype_input)
    # self.custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)
    # self.add_swh(building_type, building_vintage, climate_zone, prototype_input)
    # self.custom_swh_tweaks(building_type, building_vintage, climate_zone, prototype_input)
    self.add_exterior_lights(building_type, building_vintage, climate_zone, prototype_input)
    self.add_occupancy_sensors(building_type, building_vintage, climate_zone)
    #self.add_design_days_and_weather_file(building_type, building_vintage, climate_zone)
    # self.set_sizing_parameters(building_type, building_vintage)
    # self.yearDescription.get.setDayofWeekforStartDay('Sunday')

    # set climate zone and building type
    # self.getBuilding.setStandardsBuildingType(building_type)
    if climate_zone.include? 'ASHRAE 169-2006-'
      self.getClimateZones.setClimateZone("ASHRAE",climate_zone.gsub('ASHRAE 169-2006-',''))
    end

    applicable = true
    if heating_source == "NA" and cooling_source == "NA"
      applicable = false
    else
      runner.registerInfo("Removing existing HVAC and replacing with heating_source='#{heating_source}' and cooling_source='#{cooling_source}'.")
      HelperMethods.remove_all_hvac_equipment(self, runner)
      floor_area = OpenStudio::convert(floor_area,"m^2","ft^2").get
      runner.registerInfo("Applying HVAC system with heating_source='#{heating_source}' and cooling_source='#{cooling_source}', num_floors='#{num_floors}' and floor_area='#{floor_area.round}' ft^2.")
      result = apply_new_commercial_hvac(self, runner, building_type, building_vintage, heating_source, cooling_source, num_floors, floor_area)
      return false if !result
    end  

    # Perform a sizing run
    if self.runSizingRun("#{sizing_run_dir}/SizingRun1") == false
      return false
    end

    # If there are any multizone systems, set damper positions
    # and perform a second sizing run
    has_multizone_systems = false
    self.getAirLoopHVACs.sort.each do |air_loop|
      # DLM: fix this, what happened to is_multizone_vav_system
      if air_loop.multizone_vav_system?
        self.apply_multizone_vav_outdoor_air_sizing(building_vintage)
        if self.runSizingRun("#{sizing_run_dir}/SizingRun2") == false
          return false
        end
        break
      end
    end

    # Apply the prototype HVAC assumptions
    # which include sizing the fan pressure rises based
    # on the flow rate of the system.
    # self.applyPrototypeHVACAssumptions(building_type, building_vintage, climate_zone)
        
    # Apply the HVAC efficiency standard
    # self.applyHVACEfficiencyStandard(building_vintage, climate_zone)

    # Add daylighting controls per standard
    # only four zones in large hotel have daylighting controls
    # todo: YXC to merge to the main function
    # if building_type != "LargeHotel"
    # self.addDaylightingControls(building_vintage)
    # else
      # self.add_daylighting_controls(building_vintage)
    # end

    if building_type == "QuickServiceRestaurant" || building_type == "FullServiceRestaurant" || building_type == "Outpatient"
      self.update_exhaust_fan_efficiency(building_vintage)
    end
    
    if building_type == "HighriseApartment"
      self.update_fan_efficiency
    end

    # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
    # AHU1 doesn't have economizer
    if building_type == "Outpatient"
      # remove the controller:mechanical ventilation for AHU1 OA
      self.modify_OAcontroller(building_vintage)
      # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
      self.reset_or_room_vav_minimum_damper(prototype_input, building_vintage)
    end

    # Add output variables for debugging
    if debug
      self.request_timeseries_outputs
    end

    # Finished
    model_status = 'final'
    self.save(OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.osm"), true)

    return true    
  end

  # Get the list of all conditioned spaces, as defined for each building in the
  # system_to_space_map inside the Prototype.building_name
  # e.g. (Prototype.secondary_school.rb) file.
  #
  # @param (see #add_constructions)
  # @return [Array<String>] returns an array of space names as strings
  def find_conditioned_space_names(building_type, building_vintage, climate_zone)
      system_to_space_map = self.define_hvac_system_map(building_type, building_vintage, climate_zone)
      conditioned_space_names = OpenStudio::StringVector.new
      system_to_space_map.each do |system|
        system['space_names'].each do |space_name|
          conditioned_space_names << space_name
        end
      end
      return conditioned_space_names
  end 
  
  def define_hvac_system_map(building_type, building_vintage, climate_zone)
  
    system_to_space_map = []
  
    self.getBuildingStorys.each do |building_story|
  
      space_names = []
      building_story.spaces.each do |space|
        space_names << space.name.to_s
      end
    
      system_to_space_map << {'space_names' => space_names}
   
    end
  
    return system_to_space_map
  end
     
  def update_exhaust_fan_efficiency(building_vintage)
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      self.getFanZoneExhausts.sort.each do |exhaust_fan|
        fan_name = exhaust_fan.name.to_s
        if fan_name.include? "Dining"
          exhaust_fan.setFanEfficiency(1)
          exhaust_fan.setPressureRise(0)
        end
      end
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      self.getFanZoneExhausts.sort.each do |exhaust_fan|
        exhaust_fan.setFanEfficiency(1)
        exhaust_fan.setPressureRise(0.000001)
      end
    end
  end       
     
  # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
  # AHU1 doesn't have economizer       
  def modify_OAcontroller(building_vintage)
    self.getAirLoopHVACs.each do |air_loop|
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      # AHU1 OA doesn't have controller:mechanicalventilation
      if air_loop.name.to_s.include? "Outpatient F1"
        controller_mv.setAvailabilitySchedule(self.alwaysOffDiscreteSchedule)
        # add minimum fraction of outdoor air schedule to AHU1
        controller_oa.setMinimumFractionofOutdoorAirSchedule(self.add_schedule('OutPatientHealthCare AHU-1_OAminOAFracSchedule'))
      # for AHU2, at vintages '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', the minimum OA schedule is not the same as
      # airloop availability schedule, but separately assigned.
      elsif building_vintage=='90.1-2004' || building_vintage=='90.1-2007' || building_vintage=='90.1-2010' || building_vintage=='90.1-2013'
        controller_oa.setMinimumOutdoorAirSchedule(self.add_schedule('OutPatientHealthCare BLDG_OA_SCH'))
        # add minimum fraction of outdoor air schedule to AHU2
        controller_oa.setMinimumFractionofOutdoorAirSchedule(self.add_schedule('OutPatientHealthCare BLDG_OA_FRAC_SCH'))
      end
    end
  end
     
  # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
  def reset_or_room_vav_minimum_damper(prototype_input, building_vintage)
    case building_vintage
    when '90.1-2004', '90.1-2007'
      return true
    when '90.1-2010', '90.1-2013'
      self.getAirTerminalSingleDuctVAVReheats.sort.each do |airterminal|
        airterminal_name = airterminal.name.get
        if airterminal_name.include? "Floor 1 Operating Room 1" or airterminal_name.include? "Floor 1 Operating Room 2"
          airterminal.setZoneMinimumAirFlowMethod('Scheduled')
          airterminal.setMinimumAirFlowFractionSchedule(add_schedule("OutPatientHealthCare OR_MinSA_Sched"))
        end
      end
    end
  end
   
end
  
def apply_new_commercial_hvac(model, runner, building_type, building_vintage, heating_source, cooling_source, num_floors, floor_area)

    heating_cooling = "#{heating_source}_#{cooling_source}"
    
    search_criteria = {
      'template' => building_vintage,
      'building_type' => building_type
    }
    prototype_input = model.find_object($os_standards['prototype_inputs'], search_criteria)     
    
    equip_applied = nil
    
    case heating_cooling
    when "Gas_Electric"
                  
        if num_floors < 3 or floor_area < 75000          
                
            fan_position = "BlowThrough" # BlowThrough, DrawThrough
            fan_type = "ConstantVolume"
            heating_type = "Gas" # Gas, Water, Single Speed Heat Pump, Water To Air Heat Pump
            supplemental_heating_type = nil # Electric, Gas
            cooling_type = "Single Speed DX AC" # Water, Two Speed DX AC, Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump              
        
            model.add_psz_ac(nil, 
                             nil, 
                             nil, # Typically nil unless water source hp
                             nil, # Typically nil unless water source hp
                             HelperMethods.zones_with_thermostats(model.getThermalZones), 
                             nil,
                             nil,
                             fan_position, 
                             fan_type,
                             heating_type,
                             supplemental_heating_type,
                             cooling_type)
                             
            equip_applied = "PSZ-AC"
        
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)   
        
            hot_water_loop = model.add_hw_loop('NaturalGas')

            model.add_pvav(building_vintage, 
                           nil, 
                           HelperMethods.zones_with_thermostats(model.getThermalZones), 
                           nil,
                           nil,
                           hot_water_loop,
                           nil)

            equip_applied = "PVAV"
        
        elsif num_floors > 5 or floor_area > 150000       
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            vav_operation_schedule = nil
            vav_oa_damper_schedule = nil
            vav_fan_efficiency = nil
            vav_fan_motor_efficiency = nil
            vav_fan_pressure_rise = nil
        
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 model.add_hw_loop('NaturalGas'), 
                                 model.add_chw_loop(nil, chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess),
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)
        
            equip_applied = "VAV w/reheat"
        
        end
    
    when "Electric_Electric"
    
        if num_floors < 3 or floor_area < 75000    
    
            fan_position = "BlowThrough" # BlowThrough, DrawThrough
            fan_type = "Cycling"
            heating_type = "Single Speed Heat Pump" # Gas, Water, Single Speed Heat Pump, Water To Air Heat Pump
            supplemental_heating_type = "Electric" # Electric, Gas
            cooling_type = "Single Speed DX AC" # Water, Two Speed DX AC, Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump    
                
            model.add_psz_ac(nil, 
                             nil, 
                             nil, # Typically nil unless water source hp
                             nil, # Typically nil unless water source hp
                             HelperMethods.zones_with_thermostats(model.getThermalZones), 
                             nil,
                             nil,
                             fan_position, 
                             fan_type,
                             heating_type,
                             supplemental_heating_type,
                             cooling_type)
                             
            equip_applied = "PSZ-AC"
    
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)
        
            model.add_pvav_pfp_boxes(model,
                                     nil, 
                                     nil, 
                                     HelperMethods.zones_with_thermostats(model.getThermalZones),
                                     nil,
                                     nil,
                                     prototype_input['vav_fan_efficiency'],
                                     prototype_input['vav_fan_motor_efficiency'],
                                     prototype_input['vav_fan_pressure_rise'])
                                             
            equip_applied = "PVAV w/PFP boxes"
        
        elsif num_floors > 5 or floor_area > 150000
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil     
        
            model.add_vav_pfp_boxes(nil, 
                                    nil, 
                                    model.add_chw_loop(nil, chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess),
                                    HelperMethods.zones_with_thermostats(model.getThermalZones),
                                    nil,
                                    nil,
                                    prototype_input['vav_fan_efficiency'],
                                    prototype_input['vav_fan_motor_efficiency'],
                                    prototype_input['vav_fan_pressure_rise'])

            equip_applied = "VAV w/PFP boxes"
        
        end    
    
    when "District Hot Water_Electric"       
    
        if num_floors < 3 or floor_area < 75000
                
            model.add_pvav(building_vintage, 
                           nil, 
                           HelperMethods.zones_with_thermostats(model.getThermalZones), 
                           nil,
                           nil,
                           model.add_district_hot_water_loop('NaturalGas'),
                           nil)
                           
            equip_applied = "PVAV"
        
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)

            model.add_pvav(building_vintage, 
                           nil, 
                           HelperMethods.zones_with_thermostats(model.getThermalZones), 
                           nil,
                           nil,
                           model.add_district_hot_water_loop('NaturalGas'),
                           nil)
                           
            equip_applied = "PVAV"
        
        elsif num_floors > 5 or floor_area > 150000
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            vav_operation_schedule = nil
            vav_oa_damper_schedule = nil
            vav_fan_efficiency = nil
            vav_fan_motor_efficiency = nil
            vav_fan_pressure_rise = nil          
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 model.add_district_hot_water_loop('NaturalGas'), 
                                 model.add_chw_loop(nil, chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess),
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)
            
            equip_applied = "VAV w/reheat"
        
        end    
    
    when "District Ambient Water_District Ambient Water"
        
        if num_floors < 3 or floor_area < 75000    
    
          chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
          chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
          chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
          chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
          chiller_capacity_guess = nil
          
          lower_loop_temp_f = 80.0
          upper_loop_temp_f = 40.0
          ambient_loop = model.add_district_ambient_loop(lower_loop_temp_f, upper_loop_temp_f)
  
          vav_operation_schedule = nil
          doas_oa_damper_schedule = nil
          doas_fan_maximum_flow_rate = nil
          doas_economizer_control_type = "FixedDryBulb" # FixedDryBulb
          energy_recovery = true
                       
          model.add_doas(nil, 
                         nil,
                         ambient_loop, 
                         ambient_loop,
                         HelperMethods.zones_with_thermostats(model.getThermalZones),
                         vav_operation_schedule,
                         doas_oa_damper_schedule,
                         doas_fan_maximum_flow_rate,
                         doas_economizer_control_type,
                         nil,
                         energy_recovery)
                           
          equip_applied = "Zone Water-to-Air HP w/DOAS"

        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)
        
          chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
          chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
          chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
          chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
          chiller_capacity_guess = nil
        
          lower_loop_temp_f = 80.0
          upper_loop_temp_f = 40.0
          ambient_loop = model.add_district_ambient_loop(lower_loop_temp_f, upper_loop_temp_f)
          
          model.add_vav_reheat(building_vintage, 
                               nil, 
                               model.add_hw_loop('HeatPump', nil, ambient_loop), 
                               model.add_chw_loop(nil, chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess, ambient_loop),
                               HelperMethods.zones_with_thermostats(model.getThermalZones),
                               nil,
                               nil,
                               prototype_input['vav_fan_efficiency'],
                               prototype_input['vav_fan_motor_efficiency'],
                               prototype_input['vav_fan_pressure_rise'],
                               nil)
                               
          equip_applied = "VAV w/Heat Pumps"
                  
        elsif num_floors > 5 or floor_area > 150000
        
          chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
          chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
          chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
          chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
          chiller_capacity_guess = nil
        
          lower_loop_temp_f = 80.0
          upper_loop_temp_f = 40.0
          ambient_loop = model.add_district_ambient_loop(lower_loop_temp_f, upper_loop_temp_f)
          
          model.add_vav_reheat(building_vintage, 
                               nil, 
                               model.add_hw_loop('HeatPump', nil, ambient_loop), 
                               model.add_chw_loop(nil, chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess, ambient_loop),
                               HelperMethods.zones_with_thermostats(model.getThermalZones),
                               nil,
                               nil,
                               prototype_input['vav_fan_efficiency'],
                               prototype_input['vav_fan_motor_efficiency'],
                               prototype_input['vav_fan_pressure_rise'],
                               nil)
                               
          equip_applied = "VAV w/Heat Pumps"
        
        end                              
    
    when "Gas_District Chilled Water"      
    
        if num_floors < 3 or floor_area < 75000
                
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil                
                
            fan_position = "BlowThrough" # BlowThrough, DrawThrough
            fan_type = "ConstantVolume"
            heating_type = "Water" # Gas, Water, Single Speed Heat Pump, Water To Air Heat Pump
            supplemental_heating_type = nil # Electric, Gas
            cooling_type = "Water" # Water, Two Speed DX AC, Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump
        
            model.add_psz_ac(nil, 
                             nil, 
                             model.add_hw_loop('NaturalGas'), # Typically nil unless water source hp
                             model.add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess), # Typically nil unless water source hp
                             HelperMethods.zones_with_thermostats(model.getThermalZones), 
                             nil,
                             nil,
                             fan_position, 
                             fan_type,
                             heating_type,
                             supplemental_heating_type,
                             cooling_type)
                             
            equip_applied = "PSZ-AC"
        
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            vav_operation_schedule = nil
            vav_oa_damper_schedule = nil
            vav_fan_efficiency = nil
            vav_fan_motor_efficiency = nil
            vav_fan_pressure_rise = nil             
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 model.add_hw_loop('NaturalGas'), 
                                 model.add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess),
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)
                                 
            equip_applied = "VAV w/reheat"
        
        elsif num_floors > 5 or floor_area > 150000
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            vav_operation_schedule = nil
            vav_oa_damper_schedule = nil
            vav_fan_efficiency = nil
            vav_fan_motor_efficiency = nil
            vav_fan_pressure_rise = nil
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 model.add_hw_loop('NaturalGas'), 
                                 model.add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess),
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)
            
            equip_applied = "VAV w/reheat"
        
        end    
    
    when "Electric_District Chilled Water"
    
        if num_floors < 3 or floor_area < 75000
                
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil                
                
            fan_position = "BlowThrough" # BlowThrough, DrawThrough
            fan_type = "ConstantVolume"
            heating_type = "Single Speed Heat Pump" # Gas, Water, Single Speed Heat Pump, Water To Air Heat Pump
            supplemental_heating_type = "Electric" # Electric, Gas
            cooling_type = "Water" # Water, Two Speed DX AC, Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump
        
            model.add_psz_ac(nil, 
                             nil,
                             nil, # Typically nil unless water source hp
                             model.add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess), # Typically nil unless water source hp
                             HelperMethods.zones_with_thermostats(model.getThermalZones), 
                             nil,
                             nil,
                             fan_position, 
                             fan_type,
                             heating_type,
                             supplemental_heating_type,
                             cooling_type)
                             
            equip_applied = "PSZ-AC"
        
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            model.add_pvav_pfp_boxes(nil, 
                                     nil, 
                                     model.add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess),
                                     HelperMethods.zones_with_thermostats(model.getThermalZones),
                                     nil,
                                     nil,
                                     prototype_input['vav_fan_efficiency'],
                                     prototype_input['vav_fan_motor_efficiency'],
                                     prototype_input['vav_fan_pressure_rise'])
                                    
            equip_applied = "VAV w/PFP boxes"
        
        elsif num_floors > 5 or floor_area > 150000
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            model.add_vav_pfp_boxes(nil, 
                                    nil, 
                                    model.add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess),
                                    HelperMethods.zones_with_thermostats(model.getThermalZones),
                                    nil,
                                    nil,
                                    prototype_input['vav_fan_efficiency'],
                                    prototype_input['vav_fan_motor_efficiency'],
                                    prototype_input['vav_fan_pressure_rise'])
            
            equip_applied = "VAV w/PFP boxes"
        
        end    
    
    when "District Hot Water_District Chilled Water"

        if num_floors < 3 or floor_area < 75000
                
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil                
                
            fan_position = "BlowThrough" # BlowThrough, DrawThrough
            fan_type = "ConstantVolume"
            heating_type = "Water" # Gas, Water, Single Speed Heat Pump, Water To Air Heat Pump
            supplemental_heating_type = nil # Electric, Gas
            cooling_type = "Water" # Water, Two Speed DX AC, Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump
            
            model.add_psz_ac(nil, 
                             nil,
                             model.add_district_hot_water_loop('NaturalGas'), # Typically nil unless water source hp
                             model.add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess), # Typically nil unless water source hp
                             HelperMethods.zones_with_thermostats(model.getThermalZones), 
                             nil,
                             nil,
                             fan_position, 
                             fan_type,
                             heating_type,
                             supplemental_heating_type,
                             cooling_type)
                             
            equip_applied = "PSZ-AC"
        
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            vav_operation_schedule = nil
            vav_oa_damper_schedule = nil
            vav_fan_efficiency = nil
            vav_fan_motor_efficiency = nil
            vav_fan_pressure_rise = nil

            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 model.add_district_hot_water_loop('NaturalGas'), 
                                 model.add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess),
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)
            
            equip_applied = "VAV w/reheat"
        
        elsif num_floors > 5 or floor_area > 150000
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            vav_operation_schedule = nil
            vav_oa_damper_schedule = nil
            vav_fan_efficiency = nil
            vav_fan_motor_efficiency = nil
            vav_fan_pressure_rise = nil
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 model.add_district_hot_water_loop('NaturalGas'), 
                                 model.add_district_chilled_water_loop(chw_pumping_type, chiller_cooling_type, chiller_condenser_type, chiller_compressor_type, chiller_capacity_guess),
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)
                                 
            equip_applied = "VAV w/reheat"
        
        end     
    
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
  else
    runner.registerError("Unknown building type #{standards_building_type}")
  end
  
  space_type.setStandardsBuildingType(new_building_type)
  space_type.setStandardsSpaceType(new_space_type)

end

def apply_commercial(model, runner, heating_source, cooling_source)

  num_spaces = model.getSpaces.length.to_i

  result, building_type, num_floors, floor_area = prototype_building_type(model, runner)
  building_vintage = '90.1-2010'
  climate_zone = 'ASHRAE 169-2006-5A'
  
  if !result
    runner.registerError("Cannot apply building type")
    return result
  end  
    
  model.getSpaceTypes.each do |space_type|
    map_space_type(space_type, runner)
  end
  
  result = model.apply_standard(runner, building_type, building_vintage, climate_zone, heating_source, cooling_source, num_floors, floor_area)
  
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

