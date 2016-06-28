# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'fileutils'

require_relative 'resources/apply_residential_e_plus'

# start the measure
class UrbanBuildingTypeEPlus < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "UrbanBuildingTypeEPlus"
  end

  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end 

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking 
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
        
    model = runner.lastOpenStudioModel.get

    # check building space type to see if we are doing residential or commercial path
    building = model.getBuilding
    building_space_type = building.spaceType
    if building_space_type.empty?
      runner.registerError("Cannot determine building space type")
      return false
    end

    if building_space_type.get.standardsBuildingType.empty?
      runner.registerError("Cannot determine standards building type")
      return false
    end
    standards_building_type = building_space_type.get.standardsBuildingType.get	
  
    residential = false
    if ["Single-Family", "Multifamily (2 to 4 units)", "Multifamily (5 or more units)", "Mobile Home"].include? standards_building_type
      runner.registerInfo("Processing Residential Building, #{standards_building_type}")
      residential = true
    end  
  
    beopt_measures_dir = "./resources/measures/"
    if File.exists?(beopt_measures_dir)
      FileUtils.rm_rf(beopt_measures_dir)
    end  
  
    result = nil
    if residential
      beopt_measures_zip = OpenStudio::toPath(File.dirname(__FILE__) + "/resources/measures.zip")
      unzip_file = OpenStudio::UnzipFile.new(beopt_measures_zip)
      unzip_file.extractAllFiles(OpenStudio::toPath(beopt_measures_dir))	
      result = apply_residential_e_plus(workspace, runner, standards_building_type, model)
    else
      result = true
    end
    
    return result
 
  end

end 

# register the measure to be used by the application
UrbanBuildingTypeEPlus.new.registerWithApplication
