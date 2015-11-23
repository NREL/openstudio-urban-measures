# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

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
      @runner.registerError("Unknown space use #{space_use}")
      return false
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

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    result = true
    model.getSpaceTypes.each do |space_type|
      result = result && apply_space_type(space_type)
    end

    model.getThermalZones.each do |thermal_zone|
      result = result && apply_hvac(thermal_zone)
    end

    return result

  end
  
end

# register the measure to be used by the application
UrbanBuildingType.new.registerWithApplication
