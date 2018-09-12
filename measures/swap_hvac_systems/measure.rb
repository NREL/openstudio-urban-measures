# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class SwapHVACSystems < OpenStudio::Measure::ModelMeasure
  require 'openstudio-standards'

  # require all .rb files in resources folder
  Dir[File.dirname(__FILE__) + '/resources/*.rb'].each { |file| require file }

  # resource file modules
  include OsLib_HelperMethods
  include OsLib_ModelGeneration

  # human readable name
  def name
    return 'Swap HVAC Systems'
  end
  
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # see if building name contains any template values
    default_string = '90.1-2010'
    get_templates.each do |template_string|
      if model.getBuilding.name.to_s.include?(template_string)
        default_string = template_string
        next
      end
    end

    # Make argument for template (vintage)
    template = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', get_templates, true)
    template.setDisplayName('Target Standard')
    template.setDefaultValue(default_string)
    args << template

    # Make argument for HVAC heating source
    htg_src_chs = OpenStudio::StringVector.new
    htg_src_chs << 'Electricity'
    htg_src_chs << 'NaturalGas'
    htg_src_chs << 'None'
    htg_src = OpenStudio::Measure::OSArgument.makeChoiceArgument('htg_src', htg_src_chs, true)
    htg_src.setDisplayName('HVAC Heating Source')
    htg_src.setDescription('The primary source of heating used by HVAC systems in the model.')
    htg_src.setDefaultValue('NaturalGas')
    args << htg_src

    # Make argument for HVAC cooling source
    clg_src_chs = OpenStudio::StringVector.new
    clg_src_chs << 'Electricity'
    clg_src_chs << 'None'
    clg_src = OpenStudio::Measure::OSArgument.makeChoiceArgument('clg_src', clg_src_chs, true)
    clg_src.setDisplayName('HVAC Cooling Source')
    clg_src.setDescription('The primary source of cooling used by HVAC systems in the model.')
    clg_src.setDefaultValue('Electricity')
    args << clg_src


    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    args = OsLib_HelperMethods.createRunVariables(runner, model, user_arguments, arguments(model))
    if !args then return false end


    # report initial condition of model
    initial_objects = model.getModelObjects.size
    runner.registerInitialCondition("The building started with #{initial_objects} objects.")

    # open channel to log messages
    OsLib_HelperMethods.setup_log_msgs(runner)

    # Make the standard applier
    standard = Standard.build((args['template']).to_s)


    cooling = 1
    if args['clg_src']=='None'
      cooling = 0
      args['clg_src']='Electricity'
    end

    heating = 1
    if args['htg_src']=='None'
      heating = 0
      args['htg_src']='NaturalGas'
    end



    # identify primary building type (used for construction, and ideally HVAC as well)  
    building_types = {}
    model.getSpaceTypes.each do |space_type|
      # populate hash of building types
      if space_type.standardsBuildingType.is_initialized
        bldg_type = space_type.standardsBuildingType.get
        if !building_types.key?(bldg_type)
          building_types[bldg_type] = space_type.floorArea
        else
          building_types[bldg_type] += space_type.floorArea
        end
      else
        runner.registerWarning("Can't identify building type for #{space_type.name}")
      end
    end
    primary_bldg_type = building_types.key(building_types.values.max) # TODO: - this fails if no space types, or maybe just no space types with standards
    lookup_building_type = standard.model_get_lookup_name(primary_bldg_type) # Used for some lookups in the standards gem
    model.getBuilding.setStandardsBuildingType(primary_bldg_type)
    climate_zone = standard.model_get_building_climate_zone_and_building_type(model)['climate_zone']

    # add hvac system ---------
    # remove HVAC objects
    standard.model_remove_prm_hvac(model)

    # Set the hvac delivery type enum
    hvac_delivery ='air'

    # Group the zones by occupancy type.  Only split out
    # non-dominant groups if their total area exceeds the limit.
    sys_groups = standard.model_group_zones_by_type(model, OpenStudio.convert(20_000, 'ft^2', 'm^2').get)

    # For each group, infer the HVAC system type.
    sys_groups.each do |sys_group|
      # Infer the primary system type
      # runner.registerInfo("template = #{args['template']}, climate_zone = #{climate_zone}, occ_type = #{sys_group['type']}, hvac_delivery = #{hvac_delivery}, htg_src = #{args['htg_src']}, clg_src = #{args['clg_src']}, area_ft2 = #{sys_group['area_ft2']}, num_stories = #{sys_group['stories']}")
      sys_type, central_htg_fuel, zone_htg_fuel, clg_fuel = standard.model_typical_hvac_system_type(model,
                                                                                                    climate_zone,
                                                                                                    sys_group['type'],
                                                                                                    hvac_delivery,
                                                                                                    args['htg_src'],
                                                                                                    args['clg_src'],
                                                                                                    OpenStudio.convert(sys_group['area_ft2'], 'ft^2', 'm^2').get,
                                                                                                    sys_group['stories'])

      # Infer the secondary system type for multizone systems
      sec_sys_type = case sys_type
                     when 'PVAV Reheat', 'VAV Reheat'
                       'PSZ-AC'
                     when 'PVAV PFP Boxes', 'VAV PFP Boxes'
                       'PSZ-HP'
                     else
                       sys_type # same as primary system type
                     end

      # Group zones by story
      story_zone_lists = standard.model_group_zones_by_story(model, sys_group['zones'])

      # On each story, add the primary system to the primary zones
      # and add the secondary system to any zones that are different.
      story_zone_lists.each do |story_group|
        # Differentiate primary and secondary zones, based on
        # operating hours and internal loads (same as 90.1 PRM)
        pri_sec_zone_lists = standard.model_differentiate_primary_secondary_thermal_zones(model, story_group)
        # Add the primary system to the primary zones
        standard.model_add_hvac_system(model, sys_type, central_htg_fuel, zone_htg_fuel, clg_fuel, pri_sec_zone_lists['primary'])
        # Add the secondary system to the secondary zones (if any)
        if !pri_sec_zone_lists['secondary'].empty?
          standard.model_add_hvac_system(model, sec_sys_type, central_htg_fuel, zone_htg_fuel, clg_fuel, pri_sec_zone_lists['secondary'])
        end
      end
    end

    # remove everything but spaces, zones, and stub space types (extend as needed for additional objects, may make bool arg for this)
    model.purgeUnusedResourceObjects
    objects_after_cleanup = initial_objects - model.getModelObjects.size
    if objects_after_cleanup > 0
      runner.registerInfo("Removing #{objects_after_cleanup} objects from model")
    end




    if heating == 0

      # Remove all possible types of Heating Objects
      #get all coilHeatingGasObjects in model
      coilHeatingGasObjects = model.getObjectsByType("OS:Coil:Heating:Gas".to_IddObjectType)

      if coilHeatingGasObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingGasObjects.")
      else
        coilHeatingGasObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingGasMultiStageObjects in model
      coilHeatingGasMultiStageObjects = model.getObjectsByType("OS:Coil:Heating:Gas:MultiStage".to_IddObjectType)

      if coilHeatingGasMultiStageObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingGasMultiStageObjects.")
      else
        coilHeatingGasMultiStageObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingGasMultiStageStageDataObjects in model
      coilHeatingGasMultiStageStageDataObjects = model.getObjectsByType("OS:Coil:Heating:Gas:MultiStage:StageData".to_IddObjectType)

      if coilHeatingGasMultiStageStageDataObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingGasMultiStageStageDataObjects.")
      else
        coilHeatingGasMultiStageStageDataObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingGasObjects in model
      coilHeatingElectricObjects = model.getObjectsByType("OS_Coil_Heating_Electric".to_IddObjectType)

      if coilHeatingElectricObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingElectricObjects.")
      else
        coilHeatingElectricObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingDXMultispeedObjects in model
      coilHeatingDXMultispeedObjects = model.getObjectsByType("OS:Coil:Heating:DX:MultiSpeed".to_IddObjectType)

      if coilHeatingDXMultispeedObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingDXMultispeedObjects.")
      else
        coilHeatingDXMultispeedObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingDXMultispeedObjects in model
      coilHeatingDXMultispeedStageDataObjects = model.getObjectsByType("OS:Coil:Heating:DX:MultiSpeed:StageData".to_IddObjectType)

      if coilHeatingDXMultispeedStageDataObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingDXMultispeedStageDataObjects.")
      else
        coilHeatingDXMultispeedStageDataObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingDXSinglespeedObjects in model
      coilHeatingDXSinglespeedObjects = model.getObjectsByType("OS:Coil:Heating:DX:SingleSpeed".to_IddObjectType)

      if coilHeatingDXSinglespeedObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingDXSinglespeedObjects.")
      else
        coilHeatingDXSinglespeedObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingDXVariableRefrigerantFlowObjects in model
      coilHeatingDXVariableRefrigerantFlowObjects = model.getObjectsByType("OS:Coil:Heating:DX:VariableRefrigerantFlow".to_IddObjectType)

      if coilHeatingDXVariableRefrigerantFlowObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingDXVariableRefrigerantFlowObjects.")
      else
        coilHeatingDXVariableRefrigerantFlowObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingDXVariableSpeedObjects in model
      coilHeatingDXVariableSpeedObjects = model.getObjectsByType("OS:Coil:Heating:DX:VariableSpeed".to_IddObjectType)

      if coilHeatingDXVariableSpeedObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingDXVariableSpeedObjects.")
      else
        coilHeatingDXVariableSpeedObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingDXVariableSpeedSpeedDataObjects in model
      coilHeatingDXVariableSpeedSpeedDataObjects = model.getObjectsByType("OS:Coil:Heating:DX:VariableSpeed:SpeedData".to_IddObjectType)

      if coilHeatingDXVariableSpeedSpeedDataObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingDXVariableSpeedSpeedDataObjects.")
      else
        coilHeatingDXVariableSpeedSpeedDataObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingFourPipeBeamObjects in model
      coilHeatingFourPipeBeamObjects = model.getObjectsByType("OS:Coil:Heating:FourPipeBeam".to_IddObjectType)

      if coilHeatingFourPipeBeamObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingFourPipeBeamObjects.")
      else
        coilHeatingFourPipeBeamObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingFourPipeBeamObjects in model
      coilHeatingDesuperheaterObjects = model.getObjectsByType("OS:Coil:Heating:Desuperheater".to_IddObjectType)

      if coilHeatingDesuperheaterObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingDesuperheaterObjects.")
      else
        coilHeatingDesuperheaterObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingLTRObjects in model
      coilHeatingLTRObjects = model.getObjectsByType("OS:Coil:Heating:LowTemperatureRadiant:ConstantFlow".to_IddObjectType)

      if coilHeatingLTRObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingLTRObjects.")
      else
        coilHeatingLTRObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingLTRVFObjects in model
      coilHeatingLTRVFObjects = model.getObjectsByType("OS:Coil:Heating:LowTemperatureRadiant:VariableFlow".to_IddObjectType)

      if coilHeatingLTRVFObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingLTRVFObjects.")
      else
        coilHeatingLTRVFObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingWaterObjects in model
      coilHeatingWaterObjects = model.getObjectsByType("OS:Coil:Heating:Water".to_IddObjectType)

      if coilHeatingWaterObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingWaterObjects.")
      else
        coilHeatingWaterObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingWaterBaseboardObjects in model
      coilHeatingWaterBaseboardObjects = model.getObjectsByType("OS:Coil:Heating:Water:Baseboard".to_IddObjectType)

      if coilHeatingWaterBaseboardObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingWaterBaseboardObjects.")
      else
        coilHeatingWaterBaseboardObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilHeatingWaterBaseboardRadiantObjects in model
      coilHeatingWaterBaseboardRadiantObjects = model.getObjectsByType("OS:Coil:Heating:Water:Baseboard:Radiant".to_IddObjectType)

      if coilHeatingWaterBaseboardRadiantObjects.size == 0
        runner.registerInfo("The model does not contain any coilHeatingWaterBaseboardRadiantObjects.")
      else
        coilHeatingWaterBaseboardRadiantObjects.each do |coil|
          coil.remove
        end
      end

      runner.registerInfo("Heating has been removed")
    end


    if cooling == 0

      # Remove all possible types of Cooling Objects
      #get all coilCoolingCooledBeamObjects in model
      coilCoolingCooledBeamObjects = model.getObjectsByType("OS:Coil:Cooling:CooledBeam".to_IddObjectType)

      if coilCoolingCooledBeamObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingCooledBeamObjects.")
      else
        coilCoolingCooledBeamObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingDXMultiSpeedObjects in model
      coilCoolingDXMultiSpeedObjects = model.getObjectsByType("OS:Coil:Cooling:DX:MultiSpeed".to_IddObjectType)

      if coilCoolingDXMultiSpeedObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingDXMultiSpeedObjects.")
      else
        coilCoolingDXMultiSpeedObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingDXMultiSpeedStageDataObjects in model
      coilCoolingDXMultiSpeedStageDataObjects = model.getObjectsByType("OS:Coil:Cooling:DX:MultiSpeed:StageData".to_IddObjectType)

      if coilCoolingDXMultiSpeedStageDataObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingDXMultiSpeedStageDataObjects.")
      else
        coilCoolingDXMultiSpeedStageDataObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingDXSingleSpeedObjects in model
      coilCoolingDXSingleSpeedObjects = model.getObjectsByType("OS:Coil:Cooling:DX:SingleSpeed".to_IddObjectType)

      if coilCoolingDXSingleSpeedObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingDXSingleSpeedObjects.")
      else
        coilCoolingDXSingleSpeedObjects.each do |coil|
          coil.to_CoilCoolingDXSingleSpeed().get().setRatedTotalCoolingCapacity(0.01)
          coil.remove

          if heating == 1
            coilHeatingDXSinglespeedObjects = model.getObjectsByType("OS:Coil:Heating:DX:SingleSpeed".to_IddObjectType)

            if coilHeatingDXSinglespeedObjects.size == 0
              runner.registerInfo("The model does not contain any coilHeatingDXSinglespeedObjects.")
            else
              coilHeatingDXSinglespeedObjects.each do |coil|
                coil.to_CoilHeatingDXSingleSpeed().get().setRatedCOP(1)
              end
            end
          end


        end
      end

      #get all coilCoolingDXTwoSpeedObjects in model
      coilCoolingDXTwoSpeedObjects = model.getObjectsByType("OS:Coil:Cooling:DX:TwoSpeed".to_IddObjectType)

      if coilCoolingDXTwoSpeedObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingDXTwoSpeedObjects.")
      else
        coilCoolingDXTwoSpeedObjects.each do |coil|
          coil.remove
        end
      end


      #get all coilCoolingDXTwoStageWithHumidityControlObjects in model
      coilCoolingDXTwoStageWithHumidityControlObjects = model.getObjectsByType("OS:Coil:Cooling:DX:TwoStageWithHumidityControlMode".to_IddObjectType)

      if coilCoolingDXTwoStageWithHumidityControlObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingDXTwoStageWithHumidityControlObjects.")
      else
        coilCoolingDXTwoStageWithHumidityControlObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingDXVariableRefFlowObjects in model
      coilCoolingDXVariableRefFlowObjects = model.getObjectsByType("OS:Coil:Cooling:DX:VariableRefrigerantFlow".to_IddObjectType)

      if coilCoolingDXVariableRefFlowObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingDXVariableRefFlowObjects.")
      else
        coilCoolingDXVariableRefFlowObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingDXVariableSpeedObjects in model
      coilCoolingDXVariableSpeedObjects = model.getObjectsByType("OS:Coil:Cooling:DX:VariableSpeed".to_IddObjectType)

      if coilCoolingDXVariableSpeedObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingDXVariableSpeedObjects.")
      else
        coilCoolingDXVariableSpeedObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingDXVariableSpeedSpeedDataObjects in model
      coilCoolingDXVariableSpeedSpeedDataObjects = model.getObjectsByType("OS:Coil:Cooling:DX:VariableSpeed:SpeedData".to_IddObjectType)

      if coilCoolingDXVariableSpeedSpeedDataObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingDXVariableSpeedSpeedDataObjects.")
      else
        coilCoolingDXVariableSpeedSpeedDataObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingFourPipeBeamObjects in model
      coilCoolingFourPipeBeamObjects = model.getObjectsByType("OS:Coil:Cooling:FourPipeBeam".to_IddObjectType)

      if coilCoolingFourPipeBeamObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingFourPipeBeamObjects.")
      else
        coilCoolingFourPipeBeamObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingLTRConstantFlowObjects in model
      coilCoolingLTRConstantFlowObjects = model.getObjectsByType("OS:Coil:Cooling:LowTemperatureRadiant:ConstantFlow".to_IddObjectType)

      if coilCoolingLTRConstantFlowObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingLTRConstantFlowObjects.")
      else
        coilCoolingLTRConstantFlowObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingLTRVariableFlowObjects in model
      coilCoolingLTRVariableFlowObjects = model.getObjectsByType("OS:Coil:Cooling:LowTemperatureRadiant:VariableFlow".to_IddObjectType)

      if coilCoolingLTRVariableFlowObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingLTRVariableFlowObjects.")
      else
        coilCoolingLTRVariableFlowObjects.each do |coil|
          coil.remove
        end
      end

      #get all coilCoolingWaterObjects in model
      coilCoolingWaterObjects = model.getObjectsByType("OS:Coil:Cooling:Water".to_IddObjectType)

      if coilCoolingWaterObjects.size == 0
        runner.registerInfo("The model does not contain any coilCoolingWaterObjects.")
      else
        coilCoolingWaterObjects.each do |coil|
          coil.remove
        end
      end

      runner.registerInfo("Cooling has been removed")
    end

    if cooling == 0 && heating ==0
      standard.model_remove_prm_hvac(model)
      runner.registerInfo("heating and cooling have been removed")
    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getModelObjects.size} objects.")

    # log messages to info messages
    OsLib_HelperMethods.log_msgs

    return true
  end
end

# register the measure to be used by the application
SwapHVACSystems.new.registerWithApplication
