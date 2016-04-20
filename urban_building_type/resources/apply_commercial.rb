  
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
    def apply_standard(runner, building_type, building_vintage, climate_zone, sizing_run_dir = Dir.pwd, debug = false)
      
        logStream = OpenStudio::StringStreamLogSink.new
        logStream.setLogLevel(OpenStudio::Warn)
        
        # begin

        lookup_building_type = self.get_lookup_name(building_type)
        
        # Retrieve the Prototype Inputs from JSON
        search_criteria = {
          'template' => building_vintage,
          'building_type' => building_type
        }
        prototype_input = self.find_object($os_standards['prototype_inputs'], search_criteria)
        if prototype_input.nil?
          runner.registerError("Could not find prototype inputs for #{search_criteria}, cannot create model.")
          return false
        end
        #self.load_building_type_methods(building_type, building_vintage, climate_zone)
        #self.load_geometry(building_type, building_vintage, climate_zone)
        #self.getBuilding.setName("#{building_vintage}-#{building_type}-#{climate_zone} created: #{Time.new}")
        space_type_map = self.define_space_type_map(building_type, building_vintage, climate_zone)
        self.assign_space_type_stubs(lookup_building_type, building_vintage, space_type_map)      
        self.add_loads(building_vintage, climate_zone)
        self.apply_infiltration_standard(building_vintage)
        self.modify_infiltration_coefficients(building_type, building_vintage, climate_zone)
        self.modify_surface_convection_algorithm(building_vintage)
        self.add_constructions(lookup_building_type, building_vintage, climate_zone)
        self.create_thermal_zones(building_type, building_vintage, climate_zone)
        # TODO: 90.1-2010, MediumOffice has no chw_pumping_type
        prototype_input['chw_pumping_type'] = 'const_pri'
        ###
        self.add_hvac(building_type, building_vintage, climate_zone, prototype_input)
        # self.custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)
        self.add_swh(building_type, building_vintage, climate_zone, prototype_input)
        self.add_exterior_lights(building_type, building_vintage, climate_zone, prototype_input)
        self.add_occupancy_sensors(building_type, building_vintage, climate_zone)
        self.add_design_days_and_weather_file(building_type, building_vintage, climate_zone)
        self.set_sizing_parameters(building_type, building_vintage)
        self.getYearDescription.setDayofWeekforStartDay('Sunday')
        
        # Perform a sizing run
        if self.runSizingRun("#{sizing_run_dir}/SizingRun1") == false
          return false
        end
        
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
        
        # Apply the prototype HVAC assumptions
        # which include sizing the fan pressure rises based
        # on the flow rate of the system.
        self.applyPrototypeHVACAssumptions(building_type, building_vintage, climate_zone)
        
        # Apply the HVAC efficiency standard
        # self.applyHVACEfficiencyStandard(building_vintage, climate_zone)
        
        # Add daylighting controls per standard
        # only four zones in large hotel have daylighting controls
        # todo: YXC to merge to the main function
        if building_type != "LargeHotel"
          self.addDaylightingControls(building_vintage)
        else
          self.add_daylighting_controls(building_vintage)
        end
        
        if building_type == "QuickServiceRestaurant" || building_type == "FullServiceRestaurant"
          self.update_exhaust_fan_efficiency(building_vintage)
        end
        
        if building_type == "HighriseApartment"
          self.update_fan_efficiency
        end
       
        # Add output variables for debugging
        if debug
          self.request_timeseries_outputs
        end
        
      # rescue Exception => e  
      
        # runner.registerError("#{e}")
        
        # # print log messages
        # logStream.logMessages.each do |logMessage|
          # if logMessage.logLevel < OpenStudio::Warn
            # runner.registerInfo(logMessage.logMessage)
          # elsif logMessage.logLevel == OpenStudio::Warn
            # runner.registerWarning(logMessage.logMessage)
          # else
            # runner.registerError(logMessage.logMessage)
          # end
        # end
        # return false
        
      # end
       
        return true    
    end
      
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
      
    # Get the name of the building type used in lookups
    #
    # @param building_type [String] the building type
    #   a .osm file in the /resources directory
    # @return [String] returns the lookup name as a string
    # @todo Unify the lookup names and eliminate this method
    def get_lookup_name(building_type)

        lookup_name = building_type

        case building_type
        when 'SmallOffice'
          lookup_name = 'Office'
        when 'MediumOffice'
          lookup_name = 'Office'
        when 'LargeOffice'
          lookup_name = 'Office'
        when 'RetailStandalone'
          lookup_name = 'Retail'
        when 'RetailStripmall'
          lookup_name = 'StripMall'
        end

        return lookup_name

    end  
      
    # Reads in a mapping between names of space types and
    # names of spaces in the model, creates an empty OpenStudio::Model::SpaceType
    # (no loads, occupants, schedules, etc.) for each space type, and assigns this
    # space type to the list of spaces named.  Later on, these empty space types
    # can be used as keys in a lookup to add loads, schedules, and
    # other inputs that are either typical or governed by a standard.
    #
    # @param building_type [String] the name of the building type
    # @param space_type_map [Hash] a hash where the key is the space type name
    #   and the value is a vector of space names that should be assigned this space type.
    #   The hash for each building is defined inside the Prototype.building_name
    #   e.g. (Prototype.secondary_school.rb) file.
    # @return [Bool] returns true if successful, false if not
    def assign_space_type_stubs(building_type, building_vintage, space_type_map)

        space_type_map.each do |space_type_name, space_names|
          # Create a new space type
          stub_space_type = OpenStudio::Model::SpaceType.new(self)
          stub_space_type.setStandardsBuildingType(building_type)
          stub_space_type.setStandardsSpaceType(space_type_name)
          stub_space_type.setName("#{building_type} #{space_type_name}")
          stub_space_type.set_rendering_color(building_vintage)

          space_names.each do |space_name|
            space = self.getSpaceByName(space_name)
            next if space.empty?
            space = space.get
            space.setSpaceType(stub_space_type)

            #OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Setting #{space.name} to #{building_type}.#{space_type_name}")
          end
        end

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
      
        system_to_space_map << {'type' => 'VAV', 'name' => "VAV #{building_story.name}", 'space_names' => space_names}
     
      end
    
      return system_to_space_map
    end    
   
    def load_building_type_methods(runner, building_type)

      building_methods = nil

      case building_type
      when 'SecondarySchool'
        building_methods = 'Prototype.secondary_school'    
      when 'PrimarySchool'
        building_methods = 'Prototype.primary_school'
      when 'SmallOffice'
        building_methods = 'Prototype.small_office'
      when 'MediumOffice'
        building_methods = 'Prototype.medium_office'
      when 'LargeOffice'
        building_methods = 'Prototype.large_office'
      when 'SmallHotel'
        building_methods = 'Prototype.small_hotel'
      when 'LargeHotel'
        building_methods = 'Prototype.large_hotel'
      when 'Warehouse'
        building_methods = 'Prototype.warehouse'
      when 'RetailStandalone'
        building_methods = 'Prototype.retail_standalone'
      when 'RetailStripmall'
        building_methods = 'Prototype.retail_stripmall'
      when 'QuickServiceRestaurant'
        building_methods = 'Prototype.quick_service_restaurant'
      when 'FullServiceRestaurant'
        building_methods = 'Prototype.full_service_restaurant'
      when 'Hospital'
        building_methods = 'Prototype.hospital'
      when 'Outpatient'
        building_methods = 'Prototype.outpatient'
      when 'MidriseApartment'
        building_methods = 'Prototype.mid_rise_apartment'
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model',"Building Type = #{building_type} not recognized")
        return false
      end

      spec = Gem::Specification.find_by_name("openstudio-standards")
      gem_root = spec.gem_dir
      require "#{gem_root}/lib/openstudio-standards/prototypes/#{building_methods}"

      return true

    end 
   
end
  
def apply_new_commercial_hvac(model, runner, building_type, building_vintage, heating_source, cooling_source, num_floors, floor_area)

    heating_cooling = "#{heating_source}_#{cooling_source}"
    
    search_criteria = {
      'template' => building_vintage,
      'building_type' => building_type
    }
    prototype_input = model.find_object($os_standards['prototype_inputs'], search_criteria)     
    
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
        
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)   
        
            hot_water_loop = model.add_hw_loop('NaturalGas')

            model.add_pvav(building_vintage, 
                           nil, 
                           HelperMethods.zones_with_thermostats(model.getThermalZones), 
                           nil,
                           nil,
                           hot_water_loop,
                           nil)       
        
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
        
            hot_water_loop = model.add_hw_loop('NaturalGas')
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)            
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 hot_water_loop, 
                                 chilled_water_loop,
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)
        
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
    
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)
        
            HelperMethods.add_pvav_pfp_boxes(model,
                                             nil, 
                                             nil, 
                                             HelperMethods.zones_with_thermostats(model.getThermalZones),
                                             nil,
                                             nil,
                                             prototype_input['vav_fan_efficiency'],
                                             prototype_input['vav_fan_motor_efficiency'],
                                             prototype_input['vav_fan_pressure_rise'])
        
        elsif num_floors > 5 or floor_area > 150000
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)        
        
            model.add_vav_pfp_boxes(nil, 
                                    nil, 
                                    chilled_water_loop,
                                    HelperMethods.zones_with_thermostats(model.getThermalZones),
                                    nil,
                                    nil,
                                    prototype_input['vav_fan_efficiency'],
                                    prototype_input['vav_fan_motor_efficiency'],
                                    prototype_input['vav_fan_pressure_rise'])        
        
        end    
    
    when "District Hot Water_Electric"       
    
        if num_floors < 3 or floor_area < 75000
                
            hot_water_loop = model.add_hw_loop('NaturalGas')
            hot_water_loop = HelperMethods.make_district_hot_water_loop(model, runner, hot_water_loop)

            model.add_pvav(building_vintage, 
                           nil, 
                           HelperMethods.zones_with_thermostats(model.getThermalZones), 
                           nil,
                           nil,
                           hot_water_loop,
                           nil)   
        
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)
        
            hot_water_loop = model.add_hw_loop('NaturalGas')
            hot_water_loop = HelperMethods.make_district_hot_water_loop(model, runner, hot_water_loop)

            model.add_pvav(building_vintage, 
                           nil, 
                           HelperMethods.zones_with_thermostats(model.getThermalZones), 
                           nil,
                           nil,
                           hot_water_loop,
                           nil)           
        
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
        
            hot_water_loop = model.add_hw_loop('NaturalGas')
            hot_water_loop = HelperMethods.make_district_hot_water_loop(model, runner, hot_water_loop)
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)            
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 hot_water_loop, 
                                 chilled_water_loop,
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)        
        
        end    
    
    when "District Ambient Water_District Ambient Water"
    
        if num_floors < 3 or floor_area < 75000    
    
            fan_position = "BlowThrough" # BlowThrough, DrawThrough
            fan_type = "Cycling"
            heating_type = "Water To Air Heat Pump" # Gas, Water, Single Speed Heat Pump, Water To Air Heat Pump
            supplemental_heating_type = "Electric" # Electric, Gas
            cooling_type = "Water To Air Heat Pump" # Water, Two Speed DX AC, Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump     
    
            heat_pump_loop = model.add_hp_loop()
            heat_pump_loop = HelperMethods.make_district_heat_pump_loop(model, runner, heat_pump_loop)
    
            model.add_psz_ac(nil, 
                             nil, 
                             heat_pump_loop, # Typically nil unless water source hp
                             heat_pump_loop, # Typically nil unless water source hp
                             HelperMethods.zones_with_thermostats(model.getThermalZones), 
                             nil,
                             nil,
                             fan_position, 
                             fan_type,
                             heating_type,
                             supplemental_heating_type,
                             cooling_type)

        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)
        
        elsif num_floors > 5 or floor_area > 150000           
        
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
        
            hot_water_loop = model.add_hw_loop('NaturalGas')
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)
            chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)            
        
            model.add_psz_ac(nil, 
                             nil, 
                             hot_water_loop, # Typically nil unless water source hp
                             chilled_water_loop, # Typically nil unless water source hp
                             HelperMethods.zones_with_thermostats(model.getThermalZones), 
                             nil,
                             nil,
                             fan_position, 
                             fan_type,
                             heating_type,
                             supplemental_heating_type,
                             cooling_type)
        
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
        
            hot_water_loop = model.add_hw_loop('NaturalGas')
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)
            chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)                                      
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 hot_water_loop, 
                                 chilled_water_loop,
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)        
        
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
        
            hot_water_loop = model.add_hw_loop('NaturalGas')
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)
            chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)                                      
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 hot_water_loop, 
                                 chilled_water_loop,
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)         
        
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
        
        elsif num_floors == 4 or num_floors == 5 or ( floor_area >= 75000 and floor_area <= 150000)
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)
            chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)
        
            model.add_vav_pfp_boxes(nil, 
                                    nil, 
                                    chilled_water_loop,
                                    HelperMethods.zones_with_thermostats(model.getThermalZones),
                                    nil,
                                    nil,
                                    prototype_input['vav_fan_efficiency'],
                                    prototype_input['vav_fan_motor_efficiency'],
                                    prototype_input['vav_fan_pressure_rise'])        
        
        elsif num_floors > 5 or floor_area > 150000
        
            chw_pumping_type = "const_pri" # const_pri, const_pri_var_sec
            chiller_cooling_type = "AirCooled" # AirCooled, WaterCooled
            chiller_condenser_type = nil # WithCondenser, WithoutCondenser, nil
            chiller_compressor_type = nil # Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
            chiller_capacity_guess = nil
        
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)
            chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)
        
            model.add_vav_pfp_boxes(nil, 
                                    nil, 
                                    chilled_water_loop,
                                    HelperMethods.zones_with_thermostats(model.getThermalZones),
                                    nil,
                                    nil,
                                    prototype_input['vav_fan_efficiency'],
                                    prototype_input['vav_fan_motor_efficiency'],
                                    prototype_input['vav_fan_pressure_rise'])        
        
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
        
            hot_water_loop = model.add_hw_loop('NaturalGas')
            hot_water_loop = HelperMethods.make_district_hot_water_loop(model, runner, hot_water_loop)
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)
            chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)            
        
            model.add_psz_ac(nil, 
                             nil,
                             hot_water_loop, # Typically nil unless water source hp
                             chilled_water_loop, # Typically nil unless water source hp
                             HelperMethods.zones_with_thermostats(model.getThermalZones), 
                             nil,
                             nil,
                             fan_position, 
                             fan_type,
                             heating_type,
                             supplemental_heating_type,
                             cooling_type)
        
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
        
            hot_water_loop = model.add_hw_loop('NaturalGas')
            hot_water_loop = HelperMethods.make_district_hot_water_loop(model, runner, hot_water_loop)
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)
            chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)                                      
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 hot_water_loop, 
                                 chilled_water_loop,
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)         
        
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
        
            hot_water_loop = model.add_hw_loop('NaturalGas')
            hot_water_loop = HelperMethods.make_district_hot_water_loop(model, runner, hot_water_loop)
            chilled_water_loop = model.add_chw_loop(nil,
                                                    chw_pumping_type,
                                                    chiller_cooling_type,
                                                    chiller_condenser_type,
                                                    chiller_compressor_type,
                                                    chiller_capacity_guess)
            chilled_water_loop = HelperMethods.make_district_chilled_water_loop(model, runner, chilled_water_loop)                                      
            
            model.add_vav_reheat(building_vintage, 
                                 nil, 
                                 hot_water_loop, 
                                 chilled_water_loop,
                                 HelperMethods.zones_with_thermostats(model.getThermalZones),
                                 nil,
                                 nil,
                                 prototype_input['vav_fan_efficiency'],
                                 prototype_input['vav_fan_motor_efficiency'],
                                 prototype_input['vav_fan_pressure_rise'],
                                 nil)            
        
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

    return true
    
end

# returns "Large", "Medium", or "Small"
def office_size(floor_area, runner)
  result = "Medium"
      
  # todo: put in real ranges
  if floor_area > 200000000 # FIXME: seems there is currently a bug in openstudio-standards gem when building_type='LargeOffice' (~line 716 of create_thermal_zones in Prototype.Model.rb)
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

def hotel_size(floor_area, runner)
  result = "Large"
      
  # todo: put in real ranges
  if floor_area > 2
    result = "Large"
  elsif floor_area > 1
    result = "Small"
  else
    runner.registerError("Building floor area is 0, cannot determine hotel size")
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
  when "Single-Family"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Multifamily (2 to 4 units)"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Multifamily (5 or more units)"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Mobile Home"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Vacant"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
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
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Nonrefrigerated warehouse"
    
    building_type = 'Warehouse'
    
  when "Food sales"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Public order and safety"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Outpatient health care"
    
    building_type = 'Outpatient'
    
  when "Refrigerated warehouse"
    
    building_type = 'Warehouse'
    
  when "Religious worship"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Public assembly"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Education"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Food service"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Inpatient health care"

    building_type = 'Hospital'
  
  when "Nursing"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
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
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Retail other than mall"
    
    building_type = 'RetailStandalone'
    
  when "Service"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")
    building_type = 'MediumOffice'
  when "Other"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'MediumOffice'")    
    building_type = 'MediumOffice'
  else
    runner.registerError("Unknown building type #{standards_building_type}")
  end
  
  return building_type, num_floors, floor_area

end

# map the cbecs space type to standards space type
def map_space_type(space_type, runner)
  
  standards_building_type = space_type.standardsBuildingType.get
  standards_space_type = space_type.standardsSpaceType.get
  
  new_building_type = standards_building_type
  new_space_type = standards_space_type

  floor_area = space_type.model.getBuilding.floorArea
  case standards_building_type
  when "Single-Family"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Multifamily (2 to 4 units)"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Multifamily (5 or more units)"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Mobile Home"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Vacant"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Office"
    new_building_type = 'Office' 
    
    size = office_size(floor_area, runner)
    if size == "Large"
      new_space_type = 'WholeBuilding - Lg Office'
    elsif size == "Medium"
      new_space_type = 'WholeBuilding - Md Office'
    elsif size == "Small"
      new_space_type = 'WholeBuilding - Sm Office'
    end
    
  when "Laboratory"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Nonrefrigerated warehouse"
    
    new_space_type = 'Warehouse - med/blk'
    
  when "Food sales"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Public order and safety"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Outpatient health care"
    
    new_space_type = 'Hospital - exam'
    
  when "Refrigerated warehouse"
    
    new_space_type = 'Warehouse - med/blk'
    
  when "Religious worship"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Public assembly"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Education"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Food service"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Inpatient health care"
    
    new_space_type = 'Hospital - exam'
    
  when "Nursing"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Lodging"
    new_building_type = 'Lodging' 
    
    size = hotel_size(floor_area, runner)
    if size == "Large"
      new_space_type = 'Hotel/Motel - rooms'
    elsif size == "Small"
      new_space_type = 'Hotel/Motel - rooms'
    end  
  
  when "Strip shopping mall"
    
    new_space_type = 'Retail'
    
  when "Enclosed mall"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Retail other than mall"
    
    new_space_type = 'Retail'
    
  when "Service"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  when "Other"
    runner.registerWarning("#{standards_building_type} is not a commercial building type, using 'Office'")  
    new_building_type = 'Office' 
    new_space_type = 'WholeBuilding - Md Office'
  else
    runner.registerError("Unknown building type #{standards_building_type}")
  end
  
  space_type.setStandardsBuildingType(new_building_type)
  space_type.setStandardsSpaceType(new_space_type)

end

def apply_commercial(model, runner, heating_source, cooling_source)

  num_spaces = model.getSpaces.length.to_i

  building_type, num_floors, floor_area = prototype_building_type(model, runner)
  building_vintage = '90.1-2010'
  climate_zone = 'ASHRAE 169-2006-5A'
    
  model.getSpaceTypes.each do |space_type|
    map_space_type(space_type, runner)
  end
  
  result = model.apply_standard(runner, building_type, building_vintage, climate_zone)
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
  
  applicable = true
  if heating_source == "NA" and cooling_source == "NA"
    applicable = false
  end
  if applicable
    runner.registerInfo("Removing existing HVAC and replacing with heating_source='#{heating_source}' and cooling_source='#{cooling_source}'.")
    HelperMethods.remove_existing_hvac_equipment(model, runner)
    floor_area = OpenStudio::convert(floor_area,"m^2","ft^2").get
    runner.registerInfo("Applying HVAC system with heating_source='#{heating_source}' and cooling_source='#{cooling_source}', num_floors='#{num_floors}' and floor_area='#{floor_area}'.")
    result = result && apply_new_commercial_hvac(model, runner, building_type, building_vintage, heating_source, cooling_source, num_floors, floor_area)
  end  
  
  runner.registerValue('bldg_use', building_type)
  runner.registerValue('num_spaces', num_spaces, 'spaces')
  
  return result
    
end

