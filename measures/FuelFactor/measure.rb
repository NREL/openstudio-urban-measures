# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class FuelFactor < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "FuelFactor"
  end

  # human readable description
  def description
    return "Add site to source Emissions factors to an EnergyPlus Model for a prescribed fuel type."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This Measure adds FuelFactor Object to an EnergyPlus Model."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    fuelfactor_file_name = OpenStudio::Ruleset::OSArgument.makeStringArgument('fuelfactor_file_name', true)
    fuelfactor_file_name.setDisplayName("FuelFactor File Name")
    fuelfactor_file_name.setDescription("Name of the FuelFactor IDF to change to. This is the full filename with extension (e.g. Electricity.idf).")
    fuelfactor_file_name.setDefaultValue("Electricity.idf")
    args << fuelfactor_file_name

    return args
  end 

  # Define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # Use built-in error checking
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    fuelfactor_file_name = runner.getStringArgumentValue("fuelfactor_file_name", user_arguments)

    # Find FuelFactor snippet file
    osw_file = runner.workflow.findFile(fuelfactor_file_name)
    if osw_file.is_initialized
      fuelfactor_file = osw_file.get.to_s
      runner.registerInfo("Found #{fuelfactor_file_name}")
    else
      runner.registerError("Did not find #{fuelfactor_file_name} in paths described in OSW file.")
      return false
    end

    # Load the idf file containing the FuelFactor
    file_path = OpenStudio::Path.new(fuelfactor_file)
    loaded_file = OpenStudio::IdfFile::load(file_path).get

    # Add a FuelFactors and Object:EnvironmentalImpactFactors Objects
    # http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf#nameddest=FuelFactors
    workspace.addObjects(loaded_file.getObjectsByType("FuelFactors".to_IddObjectType))
    workspace.addObjects(loaded_file.getObjectsByType("Output:EnvironmentalImpactFactors".to_IddObjectType))

    # Report final condition of model
    runner.registerFinalCondition("Added a FuelFactor Object from #{fuelfactor_file_name}.")
    runner.registerFinalCondition("Added an Output:EnvironmentalImpactFactors reporting Object from #{fuelfactor_file_name}.")

    return true
 
  end

end 

# register the measure to be used by the application
FuelFactor.new.registerWithApplication
