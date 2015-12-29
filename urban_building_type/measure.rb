# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'openstudio-standards'
require 'fileutils'

require_relative 'resources/apply_residential'
require_relative 'resources/apply_commercial'

module OpenStudio
  module Model
    class RenderingColor
      def setRGB(r, g, b)
        self.setRenderingRedValue(r)
        self.setRenderingGreenValue(g)
        self.setRenderingBlueValue(b)
      end
    end
  end
end

# start the measure
class UrbanBuildingType < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Urban Building Type"
  end

  # human readable description
  def description
    return "This measure addings space type, constructions, and schedules as well as HVAC systems based on building type."
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    @runner = runner

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    # check building space type to see if we are doing residential or commercial path
    building = model.getBuilding
    building_space_type = building.spaceType
    if building_space_type.empty?
      runner.registerError("Cannot determine building space type")
      return false
    end
    
    residential = false
    
    building_space_type_name = building_space_type.get.name.get
    if building_space_type_name == "Single-Family" || 
        building_space_type_name == "Multifamily (2 to 4 units)"
        building_space_type_name == "Multifamily (5 or more units)"
        building_space_type_name == "Mobile Home"
      runner.registerInfo("Processing Residential Building")
      residential = true
    else
      runner.registerInfo("Processing Commercial Building")
      residential = false
    end
    
    beopt_measures_dir = File.dirname(__FILE__) + "/resources/beopt-measures/"
    if File.exists?(beopt_measures_dir)
      FileUtils.rm_rf(beopt_measures_dir)
    end
    
	residential=true # tk temp
    if residential
      beopt_measures_zip = OpenStudio::toPath(File.dirname(__FILE__) + "/resources/beopt-measures.zip");
      unzip_file = OpenStudio::UnzipFile.new(beopt_measures_zip)
      unzip_file.extractAllFiles(OpenStudio::toPath(beopt_measures_dir))
    end
    
    result = nil
    if residential
      result = apply_residential(model, runner)
    else
      result = apply_commercial(model, runner)
    end
    
    if File.exists?(beopt_measures_dir)
      FileUtils.rm_rf(beopt_measures_dir)
    end
    
    return result

  end
  
end

# register the measure to be used by the application
UrbanBuildingType.new.registerWithApplication
