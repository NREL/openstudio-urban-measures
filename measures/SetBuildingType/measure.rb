#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class SetBuildingType < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Set Building Type"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    building_type = OpenStudio::Ruleset::OSArgument::makeStringArgument("building_type",true)
    building_type.setDisplayName("Building Type")
    args << building_type
    
    mixed_types = OpenStudio::Ruleset::OSArgument::makeStringArgument("mixed_types",true)
    mixed_types.setDisplayName("Mixed Types")
    mixed_types.setDefaultValue("[]")
    args << mixed_types
    
    number_of_residential_units = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("number_of_residential_units",true)
    number_of_residential_units.setDisplayName("Number of Residential Units")
    number_of_residential_units.setDefaultValue(0)
    args << number_of_residential_units  

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
    building_type_name = runner.getStringArgumentValue("building_type",user_arguments)
    mixed_types = runner.getStringArgumentValue("mixed_types",user_arguments)
    number_of_residential_units = runner.getIntegerArgumentValue("number_of_residential_units",user_arguments)
    
    if mixed_types
      mixed_types = JSON::parse(mixed_types, :symbolize_names=>true)
    end
      
    if building_type_name == "Mixed use"
      if mixed_types.nil? or mixed_types.empty?
        runner.registerError("'Mixed use' building type requested but 'mixed_types' argument is empty")
        return false
      end
    else
      if !mixed_types.empty?
        runner.registerWarning("Building type is '#{building_type_name}', 'mixed_types' argument ignored")
      end
      mixed_types = []
    end
    
    building_type = nil
    model.getSpaceTypes.each do |s|
      if s.name.get == building_type_name
        building_type = s
        break
      end
    end
    
    if building_type.nil?
      building_type = OpenStudio::Model::SpaceType.new(model)
      building_type.setName(building_type_name)
      building_type.setStandardsBuildingType(building_type_name)
      building_type.setStandardsSpaceType(building_type_name)
    end
    
    model.getBuilding.setSpaceType(building_type)
    model.getBuilding.setStandardsBuildingType(building_type_name)
    model.getBuilding.setStandardsNumberOfLivingUnits(number_of_residential_units)
    
    if building_type_name == "Mobile Home"  
      model.getBuilding.setRelocatable(true)
    else
      model.getBuilding.setRelocatable(false)
    end
   
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
SetBuildingType.new.registerWithApplication