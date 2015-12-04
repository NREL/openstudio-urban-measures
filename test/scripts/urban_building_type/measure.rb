# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

puts "GEM_PATH =" + ENV["GEM_PATH"]
puts "Gem.path =" + Gem.path.join(';')

require 'openstudio-standards'
require 'fileutils'

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
  
  def apply_space_type(space_type)
    
    space_type_name = space_type.name.get
    
    rendering_color = space_type.renderingColor
    if rendering_color.empty?
      rendering_color = OpenStudio::Model::RenderingColor.new(space_type.model)
      space_type.setRenderingColor(rendering_color)
    else
      rendering_color = rendering_color.get
    end
    
    case space_type_name
    when "Single-Family"
      rendering_color.setRGB(0, 0, 0)
    when "Multifamily (2 to 4 units)"
      rendering_color.setRGB(0, 0, 0)
    when "Multifamily (5 or more units)"
      rendering_color.setRGB(0, 0, 0)
    when "Mobile Home"
      rendering_color.setRGB(0, 0, 0)
    when "Vacant"
      rendering_color.setRGB(0, 0, 0)
    when "Office"
      rendering_color.setRGB(0, 0, 0)
    when "Laboratory"
      rendering_color.setRGB(0, 0, 0)
    when "Nonrefrigerated warehouse"
      rendering_color.setRGB(0, 0, 0)
    when "Food sales"
      rendering_color.setRGB(0, 0, 0)
    when "Public order and safety"
      rendering_color.setRGB(0, 0, 0)
    when "Outpatient health care"
      rendering_color.setRGB(0, 0, 0)
    when "Refrigerated warehouse"
      rendering_color.setRGB(0, 0, 0)
    when "Religious worship"
      rendering_color.setRGB(0, 0, 0)
    when "Public assembly"
      rendering_color.setRGB(0, 0, 0)
    when "Education"
      rendering_color.setRGB(0, 0, 0)
    when "Food service"
      rendering_color.setRGB(0, 0, 0)
    when "Inpatient health care"
      rendering_color.setRGB(0, 0, 0)
    when "Nursing"
      rendering_color.setRGB(0, 0, 0)
    when "Lodging"
      rendering_color.setRGB(0, 0, 0)
    when "Strip shopping mall"
      rendering_color.setRGB(0, 0, 0)    
    when "Enclosed mall"
      rendering_color.setRGB(0, 0, 0)
    when "Retail other than mall"
      rendering_color.setRGB(0, 0, 0)
    when "Service"
      rendering_color.setRGB(0, 0, 0)
    when "Other"
      rendering_color.setRGB(0, 0, 0)          
    else
      @runner.registerWarning("Unknown space use #{space_type_name}")
      return true
      
      #@runner.registerError("Unknown space use #{space_type_name}")
      #return false
    end
    
    return true
  end
  
  def apply_hvac(thermal_zone)
  
    cooling_schedule = OpenStudio::Model::ScheduleConstant.new(thermal_zone.model)
    cooling_schedule.setValue(25)
    
    heating_schedule = OpenStudio::Model::ScheduleConstant.new(thermal_zone.model)
    heating_schedule.setValue(20)
    
    thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(thermal_zone.model)
    thermostat.setCoolingSetpointTemperatureSchedule(cooling_schedule)
    thermostat.setHeatingSetpointTemperatureSchedule(heating_schedule)

    thermal_zone.setThermostatSetpointDualSetpoint(thermostat)
    thermal_zone.setUseIdealAirLoads(true)
    
    return true
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
      residential = true
    else
      residential = false
    end
    
    beopt_measures_dir = File.dirname(__FILE__) + "/resources/beopt-measures/"
    if File.exists?(beopt_measures_dir)
      FileUtils.rm_rf(beopt_measures_dir)
    end
    if residential
      beopt_measures_zip = OpenStudio::toPath( File.dirname(__FILE__) + "/resources/beopt-measures.zip");
      unzip_file = OpenStudio::UnzipFile.new(beopt_measures_zip)
      unzip_file.extractAllFiles(OpenStudio::toPath( beopt_measures_dir))
    end
    
    result = true
    model.getSpaceTypes.each do |space_type|
      result = result && apply_space_type(space_type)
    end

    model.getThermalZones.each do |thermal_zone|
      result = result && apply_hvac(thermal_zone)
    end
    
    ####################################################################################################################
    # hack code to get this working
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/resources/MinimalTemplate.osm")
    minimal_model = translator.loadModel(path).get

    space_type = minimal_model.getBuilding.spaceType.get.clone(model).to_SpaceType.get
    model.getBuilding.setSpaceType(space_type)
    
    default_construction_set = minimal_model.getBuilding.defaultConstructionSet.get.clone(model).to_DefaultConstructionSet.get
    model.getBuilding.setDefaultConstructionSet(default_construction_set)
    
    # have to assign constructions to adiabatic surfaces
    exterior_wall = default_construction_set.defaultExteriorSurfaceConstructions.get.wallConstruction.get
    interior_roof = default_construction_set.defaultInteriorSurfaceConstructions.get.roofCeilingConstruction.get
    interior_floor = default_construction_set.defaultInteriorSurfaceConstructions.get.floorConstruction.get
    model.getSurfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Adiabatic"
        if surface.surfaceType == "Wall" 
          surface.setConstruction(exterior_wall)
        elsif surface.surfaceType == "RoofCeiling"
          surface.setConstruction(interior_roof)
        elsif surface.surfaceType == "Floor"
          surface.setConstruction(interior_floor)          
        end
      end
    end
    
    return result

  end
  
end

# register the measure to be used by the application
UrbanBuildingType.new.registerWithApplication
