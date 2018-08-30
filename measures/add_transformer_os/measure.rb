# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class AddTransformerOS < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "Add Transformer OS Version"
  end

  # human readable description
  def description
    return "Adds a Transformer object to the model, requires Schedule named 'Transformer Output Electric Energy Schedule' to exist in the model. This schedule should be in units of Joules."
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

     #make an argument for your name
    name_plate_rating = OpenStudio::Measure::OSArgument::makeDoubleArgument("name_plate_rating",true)
    name_plate_rating.setDisplayName("Transformer rating")
    name_plate_rating.setDefaultValue(0)  # assume unknown if 0, will auto-size
    name_plate_rating.setUnits("VA")
    args << name_plate_rating

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    name_plate_rating = runner.getStringArgumentValue('name_plate_rating', user_arguments)

    # temp for debug
    # model.save('tempWORKSPACE.idf', true)

    # check for transformer schedule in the starting model
    schedules = model.getObjectsByName("Transformer Output Electric Energy Schedule")

    if schedules.empty?
      runner.registerAsNotApplicable("Transformer Output Electric Energy Schedule not found")
      return true
    end
    
    if schedules[0].iddObject.type != "OS:Schedule:Year".to_IddObjectType and
      schedules[0].iddObject.type != "OS:Schedule:Compact".to_IddObjectType
      runner.registerError("Transformer Output Electric Energy Schedule is not a Schedule:Year or a Schedule:Compact")
      return false
    end

    # DLM: these could be inputs
    name_plate_efficiency = 0.985
    unit_load_at_name_plate_efficiency = 0.35
    
    if name_plate_rating === 0
      max_energy = 0
      
      if schedules[0].iddObject.type == "Schedule:Year".to_IddObjectType
        schedules[0].targets.each do |week_target|
          if week_target.iddObject.type == "Schedule:Week:Daily".to_IddObjectType
            week_target.targets.each do |day_target|
              if day_target.iddObject.type == "Schedule:Day:Interval".to_IddObjectType
                day_target.extensibleGroups.each do |eg|
                  value = eg.getDouble(1)
                  if value.is_initialized
                    if value.get > max_energy
                      max_energy = value.get
                    end
                  end
                end
              end
            end
          end
        end
      elsif schedules[0].iddObject.type == "Schedule:Compact".to_IddObjectType
        schedules[0].extensibleGroups.each do |eg|
          if /\A[+-]?\d+?(_?\d+)*(\.\d+e?\d*)?\Z/.match(eg.getString(0).to_s.strip)
            value = eg.getDouble(0)
            if value.is_initialized
              if value.get > max_energy
                max_energy = value.get
              end
            end
          end
        end
      
      end
      runner.registerInfo("Max energy is #{max_energy} J")
      
      minutes_per_timestep = nil
      model.getObjectsByType("Timestep".to_IddObjectType).each do |timestep|
        timestep_per_hour = timestep.getDouble(0)
        if timestep_per_hour.empty? 
          runner.registerError("Cannot determine timesteps per hour")
          return false
        end
        minutes_per_timestep = 60 / timestep_per_hour.get
      end
      
      if minutes_per_timestep.nil? 
        runner.registerError("Cannot determine minutes per timestep")
        return false
      end
        
      seconds_per_timestep = minutes_per_timestep * 60
      max_power = max_energy / seconds_per_timestep
      
      runner.registerInfo("Max power is #{max_power} W")
      
      name_plate_rating = max_power/unit_load_at_name_plate_efficiency
    end
    sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,"Schedule Value")
    sensor.setKeyName("Transformer Output Electric Energy Schedule")
    sensor.setName("TransformerOutputElectricEnergyScheduleEMSSensor")   

    meteredOutputVariable = OpenStudio::Model::EnergyManagementSystemMeteredOutputVariable.new(model,sensor)
    meteredOutputVariable.setEMSVariableName(sensor.name.to_s)
    meteredOutputVariable.setUpdateFrequency("ZoneTimeStep")
    meteredOutputVariable.setResourceType("Electricity")
    meteredOutputVariable.setGroupType("Building")
    meteredOutputVariable.setEndUseCategory("ExteriorEquipment")
    meteredOutputVariable.setEndUseSubcategory("Transformers")
    meteredOutputVariable.setUnits("J")
    
    #add 8 lines to deal with E+ bug; can be removed in E+ 9.0
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName("DummyProgram")   
    program.addLine("SET N = 0")
    program.addLine("SET N = 0")
    program.addLine("SET N = 0")
    program.addLine("SET N = 0")
    program.addLine("SET N = 0")
    program.addLine("SET N = 0")
    program.addLine("SET N = 0")
    program.addLine("SET N = 0")

    pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    pcm.setName("DummyManager")
    pcm.setCallingPoint("BeginTimestepBeforePredictor")
    pcm.addProgram(program)
   
    meter = OpenStudio::Model::OutputMeter.new(model)
    meter.setName("Transformer:ExteriorEquipment:Electricity")
    meter.setReportingFrequency("Timestep")
     
    transformer = OpenStudio::Model::ElectricLoadCenterTransformer.new(model)
    transformer.setTransformerUsage("PowerInFromGrid")
    transformer.setRatedCapacity("#{name_plate_rating}".to_f)
    transformer.setPhase("3")
    transformer.setConductorMaterial("Aluminum")
    transformer.setFullLoadTemperatureRise(150)
    transformer.setFractionofEddyCurrentLosses(0.1)
    transformer.setPerformanceInputMethod("NominalEfficiency")
    transformer.setNameplateEfficiency("#{name_plate_efficiency}".to_f)
    transformer.setPerUnitLoadforNameplateEfficiency("#{unit_load_at_name_plate_efficiency}".to_f)
    transformer.setReferenceTemperatureforNameplateEfficiency(75)
    transformer.setConsiderTransformerLossforUtilityCost(true)
    transformer.addMeter("Transformer:ExteriorEquipment:Electricity")  
    runner.registerInfo("Added ElectricLoadCenterTransformer: #{transformer.name}")
    
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Efficiency", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Input Electric Power", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Input Electric Energy", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Output Electric Power", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Output Electric Energy", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer No Load Loss Rate", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer No Load Loss Energy", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Load Loss Rate", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Load Loss Energy", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Thermal Loss Rate", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Thermal Loss Energy", model)
    outputVariable.setReportingFrequency("Timestep")
    outputVariable = OpenStudio::Model::OutputVariable.new("Transformer Distribution Electric Loss Energy", model)
    outputVariable.setReportingFrequency("Timestep")
  
  
    # schedule format example:
    # Output:Variable,Transformer Output Electric Energy Schedule, Schedule Value, Timestep; !- HVAC Sum [J]
    # get all schedules and add output variables
    compactSchedules = model.getObjectsByType("Schedule:Compact".to_IddObjectType)
    runner.registerInfo("number of compact schedule retrieved:  #{compactSchedules.size}")
    constantSchedules = model.getObjectsByType("Schedule:Constant".to_IddObjectType)
    runner.registerInfo("number of constant schedules: #{constantSchedules.size}")

    allSchedules = []
    allSchedules << compactSchedules << constantSchedules
    allSchedules.flatten!
    runner.registerInfo("all schedules retrieved:  #{allSchedules.size}")
    ignoreList = ['Always On Continuous', 'Always Off Discrete', 'Always On Discrete', 'Summed District Heating Mass Flow Rate', 'Summed District Heating Hot Water Rate', 'Summed District Cooling Chilled Water Rate', 'Summed District Cooling Mass Flow Rate']

    (0...allSchedules.size).each do |index|
      tmpName = allSchedules[index].getString(0).to_s
      next if ignoreList.include? tmpName

      runner.registerInfo("Schedule: #{tmpName}")
      outputVariable = OpenStudio::Model::OutputVariable.new("Schedule Value", model)
      outputVariable.setKeyValue("#{tmpName}")
      outputVariable.setReportingFrequency("Timestep")
      
    end   

    return true

  end

end

# register the measure to be used by the application
AddTransformerOS.new.registerWithApplication
