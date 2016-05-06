# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'openstudio-standards'
require 'fileutils'

require_relative 'resources/apply_residential'
require_relative 'resources/apply_commercial'
require_relative 'resources/util'
require_relative 'resources/geometry'

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

    # heating source
    heating_sources = OpenStudio::StringVector.new
    heating_sources << "NA"
    heating_sources << "Gas"
    heating_sources << "Electric"
    heating_sources << "District Hot Water"
    heating_sources << "District Ambient Water"
    heating_source = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("heating_source", heating_sources, true)
    heating_source.setDisplayName("Heating source to model")
    heating_source.setDefaultValue("NA")
    args << heating_source    
    
    # cooling source
    cooling_sources = OpenStudio::StringVector.new
    cooling_sources << "NA"
    cooling_sources << "Electric"
    cooling_sources << "District Chilled Water"
    cooling_sources << "District Ambient Water"
    cooling_source = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("cooling_source", cooling_sources, true)
    cooling_source.setDisplayName("Cooling source to model")
    cooling_source.setDefaultValue("NA")
    args << cooling_source
    
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    cooling_source = runner.getStringArgumentValue("cooling_source", user_arguments)
    heating_source = runner.getStringArgumentValue("heating_source", user_arguments)
    if cooling_source == "NA" or heating_source == "NA"
      cooling_source = "NA"
      heating_source = "NA"
    end
    
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
    else
      runner.registerInfo("Processing Commercial Building, #{standards_building_type}")
      residential = false
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
      result = apply_residential(model, runner, heating_source, cooling_source)
    else
      result = apply_commercial(model, runner, heating_source, cooling_source)
    end
    
    return result

  end
  
end

# register the measure to be used by the application
UrbanBuildingType.new.registerWithApplication
