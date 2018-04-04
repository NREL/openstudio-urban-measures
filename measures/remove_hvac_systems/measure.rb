#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#load OpenStudio measure libraries
require "#{File.dirname(__FILE__)}/resources/OsLib_HVAC"

#start the measure
class RemoveHVACSystems < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Remove HVAC Systems"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    remove_all_equipment = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_all_equipment",true)
    remove_all_equipment.setDisplayName("Remove all HVAC systems and equipment?")
    remove_all_equipment.setDefaultValue(true)
    args << remove_all_equipment

    return args
  end

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    remove_all_equipment = runner.getBoolArgumentValue("remove_all_equipment", user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    if remove_all_equipment
      # Report initial condition of model
      OsLib_HVAC.reportConditions(model, runner, "initial")

      # Remove Air/Plant Loops and Zone Equipment
      OsLib_HVAC.removeEquipment(model, runner)

      # Report final condition of model
      OsLib_HVAC.reportConditions(model, runner, "final")
    else
      runner.registerFinalCondition("Did nothing to model HVAC systems.")
    end

    return true

  end

end

#this allows the measure to be used by the application
RemoveHVACSystems.new.registerWithApplication