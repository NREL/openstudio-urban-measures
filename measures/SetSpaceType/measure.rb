#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class SetSpaceType < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Set Space Type"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    space_type = OpenStudio::Ruleset::OSArgument::makeStringArgument("space_type",true)
    space_type.setDisplayName("Space Type")
    args << space_type

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    space_type_name = runner.getStringArgumentValue("space_type",user_arguments)
    
    space_type = nil
    model.getSpaceTypes.each do |s|
      if s.name.get == space_type_name
        space_type = s
        break
      end
    end
    
    if space_type.nil?
      space_type = OpenStudio::Model::SpaceType.new(model)
      space_type.setName(space_type_name)
      space_type.setStandardsBuildingType(space_type_name)
      space_type.setStandardsSpaceType(space_type_name)
    end
    
    model.getBuilding.setSpaceType(space_type)
    model.getBuilding.setStandardsBuildingType(space_type_name)
    
    if space_type_name == "Mobile Home"
      model.getBuilding.setStandardsNumberOfLivingUnits(1)
      model.getBuilding.setRelocatable(true)
    elsif space_type_name == "Single-Family"
      model.getBuilding.setStandardsNumberOfLivingUnits(1)
      model.getBuilding.setRelocatable(false)
    elsif space_type_name == "Multifamily (2 to 4 units)"
      model.getBuilding.setStandardsNumberOfLivingUnits(4)
      model.getBuilding.setRelocatable(false)
    elsif space_type_name == "Multifamily (5 or more units)"
      model.getBuilding.setStandardsNumberOfLivingUnits(10)
      model.getBuilding.setRelocatable(false)
    else
      model.getBuilding.setStandardsNumberOfLivingUnits(0)
      model.getBuilding.setRelocatable(false)
    end
   
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
SetSpaceType.new.registerWithApplication