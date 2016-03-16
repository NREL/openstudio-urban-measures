# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'json'
require 'net/http'

# start the measure
class UrbanGeometryCreation < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "UrbanGeometryCreation"
  end

  # human readable description
  def description
    return "This measure reads a city.json file and creates geometry for either 1 building in the dataset or all of them."
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end
  
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    # url of the city database
    city_db_url = OpenStudio::Ruleset::OSArgument.makeStringArgument("city_db_url", true)
    city_db_url.setDisplayName("City Database Url")
    city_db_url.setDescription("Url of the City Database")
	  city_db_url.setDefaultValue("http://localhost:3000")
    args << city_db_url
    
    # source id of the building to create
    source_id = OpenStudio::Ruleset::OSArgument.makeStringArgument("source_id", true)
    source_id.setDisplayName("Building Source ID")
    source_id.setDescription("Building Source ID to generate geometry for.")
    args << source_id
    
    # source name of the building to create
    source_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("source_name", true)
    source_name.setDisplayName("Building Source Name")
    source_name.setDescription("Building Source Name to generate geometry for.")
    source_name.setDefaultValue("NREL_GDS")
    args << source_name

    return args
  end
  
  def create_space_type(bldg_use, space_use, model)
    
    name = "#{bldg_use}:#{space_use}"
    
    # check if we already have this space type
    model.getSpaceTypes.each do |s|
      if s.name.get == name
        return s
      end
    end
    
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setName(name)
    space_type.setStandardsBuildingType(bldg_use)
    space_type.setStandardsSpaceType(space_use)
      
    return space_type
  end
  
  def get_multi_polygons(building_json)
    geometry_type = building_json[:geometry][:type]
    
    multi_polygons = nil
    if geometry_type == "Polygon"
      polygons = building_json[:geometry][:coordinates]
      multi_polygons = [polygons]
    elsif geometry_type == "MultiPolygon"
      multi_polygons = building_json[:geometry][:coordinates]
    end
    
    return multi_polygons
  end
  
  def floor_print_from_polygon(polygon, elevation)
  
    floor_print = OpenStudio::Point3dVector.new
    polygon.each do |p|
      lon = p[0]
      lat = p[1]
      point_3d = @origin_lat_lon.toLocalCartesian(OpenStudio::PointLatLon.new(lat, lon, 0))
      point_3d = OpenStudio::Point3d.new(point_3d.x, point_3d.y, elevation)
      floor_print << point_3d
    end
  
    if floor_print.size < 3
      @runner.registerWarning("Cannot create floor print, fewer than 3 points")
      return nil
    end
   
    floor_print = OpenStudio::removeCollinear(floor_print)
    normal = OpenStudio::getOutwardNormal(floor_print)
    if normal.empty?
      @runner.registerWarning("Cannot create floor print, cannot compute outward normal")
      return nil
    elsif normal.get.z > 0
      floor_print = OpenStudio::reverse(floor_print)
      @runner.registerWarning("Reversing floor print")
    end
    
    return floor_print
  end

  def create_building(building_json, create_method, model)
    
    properties = building_json[:properties]
    surface_elevation	= properties[:surface_elevation]
    roof_elevation	= properties[:roof_elevation]
    number_of_stories = properties[:number_of_stories]
    number_of_stories_above_ground = properties[:number_of_stories_above_ground]
    number_of_stories_below_ground = properties[:number_of_stories_below_ground]
    number_of_residential_units = properties[:number_of_residential_units]
    floor_to_floor_height = properties[:floor_to_floor_height]
    space_type = properties[:space_type]
    
    if number_of_stories_above_ground.nil?
      if number_of_stories_below_ground.nil?
        number_of_stories_above_ground = number_of_stories
        number_of_stories_below_ground = 0
      else
        number_of_stories_above_ground = number_of_stories - number_of_stories_above_ground
      end
    end
    
    if floor_to_floor_height.nil?
      floor_to_floor_height = (roof_elevation - surface_elevation) / number_of_stories_above_ground
    end
    
    if space_type
      # get the building use and fix any issues
      building_space_type = create_space_type(space_type, space_type, model)
      model.getBuilding.setSpaceType(building_space_type)
      model.getBuilding.setStandardsBuildingType(space_type)
      model.getBuilding.setRelocatable(false)
    end
    
    if number_of_residential_units
      model.getBuilding.setStandardsNumberOfLivingUnits(number_of_residential_units)
    end
    
    model.getBuilding.setStandardsNumberOfStories(number_of_stories)
    model.getBuilding.setStandardsNumberOfAboveGroundStories(number_of_stories_above_ground)
    model.getBuilding.setNominalFloortoFloorHeight(floor_to_floor_height)
    #model.getBuilding.setNominalFloortoCeilingHeight
      
    spaces = []
    if create_method == :space_per_floor
      (-number_of_stories_below_ground+1..number_of_stories_above_ground).each do |story_number|
        new_spaces = create_space_per_floor(building_json, story_number, floor_to_floor_height, model)
        spaces.concat(new_spaces)
      end
    elsif create_method == :space_per_building
      spaces = create_space_per_building(building_json, -number_of_stories_below_ground*floor_to_floor_height, number_of_stories_above_ground*floor_to_floor_height, model)
    end

    return spaces
  end

  def create_space_per_floor(building_json, story_number, floor_to_floor_height, model)
  
    geometry = building_json[:geometry] 
    properties = building_json[:properties]
    window_to_wall_ratio = properties[:window_to_wall_ratio]
    
    if window_to_wall_ratio.nil?
      window_to_wall_ratio = 0.3
    end

    floor_prints = []
    multi_polygons = get_multi_polygons(building_json)
    multi_polygons.each do |multi_polygon|
      
      if story_number == 1 && multi_polygon.size > 1
        @runner.registerWarning("Ignoring holes in polygon")
      end
      
      multi_polygon.each do |polygon|
        elevation = (story_number-1)*floor_to_floor_height
        floor_print = floor_print_from_polygon(polygon, elevation)
        if floor_print
          floor_prints << floor_print
        else 
          @runner.registerWarning("Cannot create story #{story_number}")
        end
          
        # subsequent polygons are holes, we do not support them
        break
      end
    end
    
    result = []
    floor_prints.each do |floor_print|

      space = OpenStudio::Model::Space.fromFloorPrint(floor_print, floor_to_floor_height, model)
      if space.empty?
        @runner.registerWarning("Cannot create space for story #{story_number}")
        next
      end
      space = space.get
      space.setName("Building Story #{story_number} Space")
      
      #story_space_type = create_space_type(building[:space_type], story[:space_type], model)
      #space.setSpaceType(story_space_type)
      
      bounding_box = space.boundingBox
      m = OpenStudio::Matrix.new(4,4,0)
      m[0,0] = 1
      m[1,1] = 1
      m[2,2] = 1
      m[3,3] = 1
      m[0,3] = bounding_box.minX.get
      m[1,3] = bounding_box.minY.get
      m[2,3] = bounding_box.minZ.get
      space.changeTransformation(OpenStudio::Transformation.new(m))
      
      space.surfaces.each do |surface|
        if surface.surfaceType == "Wall"
          if story_number < 1
            surface.setOutsideBoundaryCondition("Ground")
          else
            surface.setWindowToWallRatio(window_to_wall_ratio)
          end
        end
      end
        
      building_story = OpenStudio::Model::BuildingStory.new(model)
      building_story.setName("Building Story #{story_number}")
      space.setBuildingStory(building_story)
      
      thermal_zone = OpenStudio::Model::ThermalZone.new(model)
      thermal_zone.setName("Building Story #{story_number} ThermalZone")
      space.setThermalZone(thermal_zone)
      
      result << space 
    end
    
    return result
  end
  
  def create_space_per_building(building_json, min_elevation, max_elevation, model)
  
    geometry = building_json[:geometry] 
    properties = building_json[:properties]
    source_id = properties[:source_id]
    
    floor_prints = []
    multi_polygons = get_multi_polygons(building_json)
    multi_polygons.each do |multi_polygon|
      
      if multi_polygon.size > 1
        @runner.registerWarning("Ignoring holes in polygon")
      end
      
      multi_polygon.each do |polygon|
        floor_print = floor_print_from_polygon(polygon, min_elevation)
        if floor_print
          floor_prints << floor_print
        else 
          @runner.registerWarning("Cannot building #{source_id}")
        end
          
        # subsequent polygons are holes, we do not support them
        break
      end
    end
    
    result = []
    floor_prints.each do |floor_print|

      space = OpenStudio::Model::Space.fromFloorPrint(floor_print, max_elevation-min_elevation, model)
      if space.empty?
        @runner.registerWarning("Cannot create building space")
        next
      end
      space = space.get
      space.setName("Building Story #{source_id} Space")
      
      #story_space_type = create_space_type(building[:space_type], story[:space_type], model)
      #space.setSpaceType(story_space_type)
      
      bounding_box = space.boundingBox
      m = OpenStudio::Matrix.new(4,4,0)
      m[0,0] = 1
      m[1,1] = 1
      m[2,2] = 1
      m[3,3] = 1
      m[0,3] = bounding_box.minX.get
      m[1,3] = bounding_box.minY.get
      m[2,3] = bounding_box.minZ.get
      space.changeTransformation(OpenStudio::Transformation.new(m))
      
      #space.surfaces.each do |surface|
      #  if surface.surfaceType == "Wall"
      #    if story_number < 1
      #      surface.setOutsideBoundaryCondition("Ground")
      #    else
      #      surface.setWindowToWallRatio(window_to_wall_ratio)
      #    end
      #  end
      #end
        
      #building_story = OpenStudio::Model::BuildingStory.new(model)
      #building_story.setName("Building Story #{story_number}")
      #space.setBuildingStory(building_story)
      
      thermal_zone = OpenStudio::Model::ThermalZone.new(model)
      thermal_zone.setName("Building #{source_id} ThermalZone")
      space.setThermalZone(thermal_zone)
      
      result << space 
    end
    
    return result
  end
  
  def convert_to_shading_surface_group(space)
    
    name = space.name.to_s
    model = space.model
    shading_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
    
    space.surfaces.each do |surface|
      shading_surface = OpenStudio::Model::ShadingSurface.new(surface.vertices, model)
      shading_surface.setShadingSurfaceGroup(shading_group)
    end
    
    thermal_zone = space.thermalZone
    if !thermal_zone.empty?
      thermal_zone.get.remove
    end
    
    space_type = space.spaceType
    
    space.remove
    
    if !space_type.empty? && space_type.get.spaces.empty?
      space_type.get.remove
    end

    shading_group.setName(name)
    
    return [shading_group]
  end  

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    # instance variables
    @runner = runner
    @min_lon = Float::MAX 
    @min_lat = Float::MAX 

    # assign the user inputs to variables
    city_db_url = runner.getStringArgumentValue("city_db_url", user_arguments)
    source_id = runner.getStringArgumentValue("source_id", user_arguments)
    source_name = runner.getStringArgumentValue("source_name", user_arguments)
    
    port = 80
    if md = /http:\/\/(.*):(\d+)/.match(city_db_url)
      city_db_url = md[1]
      port = md[2]
    elsif /http:\/\/([^:\/]*)/.match(city_db_url)
      city_db_url = md[1]
    end
    
    params = {}
    params[:commit] = 'Search'
    params[:source_id] = source_id
    params[:source_name] = source_name
    params[:feature_types] = ['Building']
    
    http = Net::HTTP.new(city_db_url, port)
    request = Net::HTTP::Post.new("/api/search.json")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.body = JSON.generate(params)
    # DLM: todo, get these from environment variables or as measure inputs?
    request.basic_auth("testing@nrel.gov", "testing123")
  
    response = http.request(request)
    if  response.code != '200' # success
      runner.registerError("Bad response #{response.code}")
      runner.registerError(response.body)
      return false
    end

    feature_collection = JSON.parse(response.body, :symbolize_names => true)
    if feature_collection[:features].nil?
      runner.registerError("No features found in #{feature_collection}")
      return false
    elsif feature_collection[:features].empty?
      runner.registerError("No features found in #{feature_collection}")
      return false
    elsif feature_collection[:features].size > 1
      runner.registerError("Multiple features found in #{feature_collection}")
      return false
    end
    
    building_json = feature_collection[:features][0]
    
    if building_json[:geometry].nil?
      runner.registerError("No geometry found in #{building_json}")
      return false
    end
    
    geometry_type = building_json[:geometry][:type]
    if geometry_type == "Polygon"
      # ok
    elsif geometry_type == "MultiPolygon"
      # ok
    else
      runner.registerError("Unknown geometry type #{geometry_type}")
      return false
    end

    # find min and max x coordinate
    multi_polygons = get_multi_polygons(building_json)
    multi_polygons.each do |multi_polygon|
      multi_polygon.each do |polygon|
        polygon.each do |point|
          @min_lon = point[0] if point[0] < @min_lon
          @min_lat = point[1] if point[1] < @min_lat
        end
          
        # subsequent polygons are holes, we do not support them
        break
      end
    end
    
    if @min_lon == Float::MAX || @min_lat == Float::MAX 
      runner.registerError("Could not determine min_lat and min_lon")
      return false
    else
      runner.registerInfo("Min_lat = #{@min_lat}, min_lon = #{@min_lon}")
    end

    @origin_lat_lon = OpenStudio::PointLatLon.new(@min_lat, @min_lon, 0)
    
    # make requested building
    spaces = create_building(building_json, :space_per_floor, model)
    if spaces.nil? || spaces.empty?
      runner.registerError("Failed to create spaces for building #{source_id}")
      return false
    end
      
    # get nearby buildings
    convert_to_shades = []
    
    # params = {}
    # params[:commit] = 'Proximity Search'
    # params[:building_id] = building_json[:properties][:id]
    # params[:distance] = 100
    # params[:proximity_feature_types] = ['Building']
    
    # http = Net::HTTP.new(city_db_url, port)
    # request = Net::HTTP::Post.new("/api/search.json")
    # request.add_field('Content-Type', 'application/json')
    # request.add_field('Accept', 'application/json')
    # request.body = JSON.generate(params)
    # # DLM: todo, get these from environment variables or as measure inputs?
    # request.basic_auth("testing@nrel.gov", "testing123")
    
    # response = http.request(request)
    # if  response.code != '200' # success
      # runner.registerError("Bad response #{response.code}")
      # runner.registerError(response.body)
      # return false
    # end

    # feature_collection = JSON.parse(response.body, :symbolize_names => true)
    # if feature_collection[:features].nil?
      # runner.registerError("No features found in #{feature_collection}")
      # return false
    # end
    
    # feature_collection[:features].each do |other_building|
    
      # other_source_id = other_building[:properties][:source_id]
      # spaces = create_building(other_building, :space_per_building, model)
      # if spaces.nil? || spaces.empty?
        # runner.registerError("Failed to create spaces for other building #{other_source_id}")
        # return false
      # end
      
      # convert_to_shades.concat(spaces)
    # end
    
    # match surfaces
    runner.registerInfo("Matching surfaces")
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    runner.registerInfo("Changing adjacent surfaces to adiabatic")
    model.getSurfaces.each do |surface|
      adjacent_surface = surface.adjacentSurface
      if !adjacent_surface.empty?
        surface_construction = surface.construction
        if !surface_construction.empty?
          surface.setConstruction(surface_construction.get)
        end
        surface.setOutsideBoundaryCondition('Adiabatic')
        
        adjacent_surface_construction = adjacent_surface.get.construction
        if !adjacent_surface_construction.empty?
          adjacent_surface.get.setConstruction(adjacent_surface_construction.get)
        end
        adjacent_surface.get.setOutsideBoundaryCondition('Adiabatic')
      end
    end
    
    convert_to_shades.each do |space|
      convert_to_shading_surface_group(space)
    end

    return true

  end
  
end

# register the measure to be used by the application
UrbanGeometryCreation.new.registerWithApplication
