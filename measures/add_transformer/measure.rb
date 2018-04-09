# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class AddTransformer < OpenStudio::Measure::EnergyPlusMeasure

  # human readable name
  def name
    return "Add Transformer"
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
  def arguments(workspace)
    args = OpenStudio::Measure::OSArgumentVector.new

     #make an argument for your name
    name_plate_rating = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("name_plate_rating",true)
    name_plate_rating.setDisplayName("Transformer rating")
    name_plate_rating.setDefaultValue(0)  # assume unknown if 0, will auto-size
    name_plate_rating.setUnits("VA")
    args << name_plate_rating

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    # assign the user inputs to variables
    name_plate_rating = runner.getStringArgumentValue('name_plate_rating', user_arguments)

    # temp for debug
    # workspace.save('tempWORKSPACE.idf', true)

    # check for transformer schedule in the starting model
    schedules = workspace.getObjectsByName("Transformer Output Electric Energy Schedule")

     if schedules.empty?
      runner.registerAsNotApplicable("Transformer Output Electric Energy Schedule not found")
      return true
    end
    
    if schedules[0].iddObject.type != "Schedule:Year".to_IddObjectType and
      schedules[0].iddObject.type != "Schedule:Compact".to_IddObjectType
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
      workspace.getObjectsByType("Timestep".to_IddObjectType).each do |timestep|
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
    
    idf_text = "
EnergyManagementSystem:Sensor,
    TransformerOutputElectricEnergyScheduleEMSSensor, !Name
    Transformer Output Electric Energy Schedule,        ! Output:Variable or Output:Meter Index Key Name
    Schedule Value;           ! Output:Variable or Output:Meter Name
    
  EnergyManagementSystem:MeteredOutputVariable,
    Transformer Output Electric Energy Meter,!- Name
    TransformerOutputElectricEnergyScheduleEMSSensor,    !- EMS Variable Name
    ZoneTimeStep,             !- Update Frequency
    ,                         !- EMS Program or Subroutine Name
    Electricity,              !- Resource Type
    Building,                 !- Group Type
    ExteriorEquipment,        !- End-Use Category
    Transformers,             !- End-Use Subcategory
    J;                        !- Units
    
  Output:Meter,Transformers:ExteriorEquipment:Electricity,Timestep; !- [J]

  EnergyManagementSystem:ProgramCallingManager,
    DummyManager, ! Name
    EndOfZoneTimestepBeforeZoneReporting,       ! EnergyPlus Model Calling Point
    DummyProgram;

  EnergyManagementSystem:Program,
    DummyProgram,         ! Name
    SET N = 0;
    
  ElectricLoadCenter:Transformer,
    Transformer 1,                       !-Name
    Always On,                           !- Availability Schedule Name
    PowerInFromGrid,                     !- Transformer Usage
    ,                                    !- Zone Name
    ,                                    !- Radiative Fraction
    #{name_plate_rating},                 !- Nameplate Rating {VA}
    3,                                   !- Phase
    Aluminum,                            !- Conductor Material
    150,                                 !- Full Load Temperature Rise { &deg;C}
    0.1,                                 !- Fraction of Eddy Current Losses
    NominalEfficiency,                   !- Performance Input Method
    ,                                    !- Rated No Load Loss {W}
    ,                                    !- Rated Load Loss {W}
    #{name_plate_efficiency},            !- Nameplate Efficiency
    #{unit_load_at_name_plate_efficiency},                                !- Per Unit Load for Nameplate Efficiency
    75,                                  !- Reference Temperature for Nameplate Efficiency { &deg;C}
    ,                                    !- Per Unit Load for Maximum Efficiency
    Yes,                                 !- Consider Transformer Loss for Utility Cost
    Transformers:ExteriorEquipment:Electricity;                !- Meter 1 Name

  Output:Variable,*,Transformer Efficiency,Timestep; !- HVAC Average []
  Output:Variable,*,Transformer Input Electric Power,Timestep; !- HVAC Average [W]
  Output:Variable,*,Transformer Input Electric Energy,Timestep; !- HVAC Sum [J]
  Output:Variable,*,Transformer Output Electric Power,Timestep; !- HVAC Average [W]
  Output:Variable,*,Transformer Output Electric Energy,Timestep; !- HVAC Sum [J]
  Output:Variable,*,Transformer No Load Loss Rate,Timestep; !- HVAC Average [W]
  Output:Variable,*,Transformer No Load Loss Energy,Timestep; !- HVAC Sum [J]
  Output:Variable,*,Transformer Load Loss Rate,Timestep; !- HVAC Average [W]
  Output:Variable,*,Transformer Load Loss Energy,Timestep; !- HVAC Sum [J]
  Output:Variable,*,Transformer Thermal Loss Rate,Timestep; !- HVAC Average [W]
  Output:Variable,*,Transformer Thermal Loss Energy,Timestep; !- HVAC Sum [J]
  Output:Variable,*,Transformer Distribution Electric Loss Energy,Timestep; !- HVAC Sum [J]
  "
  
    # schedule format example:
    # Output:Variable,Transformer Output Electric Energy Schedule, Schedule Value, Timestep; !- HVAC Sum [J]
    # get all schedules and add output variables
    allSchedules = workspace.getObjectsByType("Schedule:Compact".to_IddObjectType)
    runner.registerInfo("number of schedule retrieved:  #{allSchedules.size}")

    (0...allSchedules.size).each do |index|
      tmpName = allSchedules[index].getString(0).to_s
      tmpUnits = ''
      if tmpName.include? ('Apparent Power')
        tmpUnits = 'VA'
      elsif tmpName.include? ('Power')
        tmpUnits = 'W'
      else
        tmpUnits = 'J'
      end
      tmpStr = "Output:Variable,#{tmpName}, Schedule Value, Timestep; !- HVAC Sum [#{tmpUnits}]"
      formattedStr ="#{tmpStr}"

      idf_text += "#{tmpStr}
  "
    end   

    #runner.registerInfo("IDF STRING: #{idf_text}")
    File.open('temp.idf', 'w') do |file|
      file << idf_text 
    end
    
    idfFile = OpenStudio::IdfFile::load(OpenStudio::Path.new('temp.idf'))
    if idfFile.empty?
      runner.registerError("Failed to parse IdfFile.")
      return false
    end
    
    idfFile = idfFile.get
    workspace.addObjects(idfFile.objects)

    return true

  end

end

# register the measure to be used by the application
AddTransformer.new.registerWithApplication
