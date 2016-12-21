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
    
    mixed_type_1 = OpenStudio::Ruleset::OSArgument::makeStringArgument("mixed_type_1",false)
    mixed_type_1.setDisplayName("Mixed Type 1")
    args << mixed_type_1
    
    mixed_type_1_percentage = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("mixed_type_1_percentage",false)
    mixed_type_1_percentage.setDisplayName("Mixed Type 1 Percentage")
    args << mixed_type_1_percentage
    
    mixed_type_2 = OpenStudio::Ruleset::OSArgument::makeStringArgument("mixed_type_2",false)
    mixed_type_2.setDisplayName("Mixed Type 2")
    args << mixed_type_2
    
    mixed_type_2_percentage = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("mixed_type_2_percentage",false)
    mixed_type_2_percentage.setDisplayName("Mixed Type 2 Percentage")
    args << mixed_type_2_percentage
    
    mixed_type_3 = OpenStudio::Ruleset::OSArgument::makeStringArgument("mixed_type_3",false)
    mixed_type_3.setDisplayName("Mixed Type 3")
    args << mixed_type_3
    
    mixed_type_3_percentage = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("mixed_type_3_percentage",false)
    mixed_type_3_percentage.setDisplayName("Mixed Type 3 Percentage")
    args << mixed_type_3_percentage
    
    mixed_type_4 = OpenStudio::Ruleset::OSArgument::makeStringArgument("mixed_type_4",false)
    mixed_type_4.setDisplayName("Mixed Type 4")
    args << mixed_type_4
    
    mixed_type_4_percentage = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("mixed_type_4_percentage",false)
    mixed_type_4_percentage.setDisplayName("Mixed Type 4 Percentage")
    args << mixed_type_4_percentage
    
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
    number_of_residential_units = runner.getIntegerArgumentValue("number_of_residential_units",user_arguments)

    mixed_types = []
    mixed_type_1 = runner.getOptionalStringArgumentValue("mixed_type_1",user_arguments)
    mixed_type_1_percentage = runner.getOptionalDoubleArgumentValue("mixed_type_1_percentage",user_arguments)
    if mixed_type_1.is_initialized && mixed_type_1_percentage.is_initialized
      mixed_types << {type: mixed_type_1.get, percentage: mixed_type_1_percentage.get}
    end
    
    mixed_type_2 = runner.getOptionalStringArgumentValue("mixed_type_2",user_arguments)
    mixed_type_2_percentage = runner.getOptionalDoubleArgumentValue("mixed_type_2_percentage",user_arguments)
    if mixed_type_2.is_initialized && mixed_type_2_percentage.is_initialized
      mixed_types << {type: mixed_type_2.get, percentage: mixed_type_2_percentage.get}
    end
    
    mixed_type_3 = runner.getOptionalStringArgumentValue("mixed_type_3",user_arguments)
    mixed_type_3_percentage = runner.getOptionalDoubleArgumentValue("mixed_type_3_percentage",user_arguments)
    if mixed_type_3.is_initialized && mixed_type_3_percentage.is_initialized
      mixed_types << {type: mixed_type_3.get, percentage: mixed_type_3_percentage.get}
    end
    
    mixed_type_4 = runner.getOptionalStringArgumentValue("mixed_type_4",user_arguments)
    mixed_type_4_percentage = runner.getOptionalDoubleArgumentValue("mixed_type_4_percentage",user_arguments)
    if mixed_type_4.is_initialized && mixed_type_4_percentage.is_initialized
      mixed_types << {type: mixed_type_4.get, percentage: mixed_type_4_percentage.get}
    end
      
    if building_type_name == "Mixed use"
      if mixed_types.empty?
        runner.registerError("'Mixed use' building type requested but 'mixed_types' argument is empty")
        return false
      end
     
      mixed_types.sort! {|x,y| x[:percentage] <=> y[:percentage]}
      
      # DLM: temp code
      building_type_name = mixed_types[-1][:type]
      runner.registerWarning("'Mixed use' building type requested, using largest type '#{building_type_name}' for now")
    else
      if !mixed_types.empty?
        runner.registerWarning("'#{building_type_name}' building type, ignoring mixed type arguments")
      end
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