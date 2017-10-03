# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'json'
require 'net/http'
require 'uri'
require 'openssl'

# start the measure
class UrbanGeometryCreation < OpenStudio::Ruleset::ModelUserScript

  attr_accessor :origin_lat_lon
  
  # human readable name
  def name
    return "UrbanGeometryCreation"
  end

  # human readable description
  def description
    return "This measure queries the URBANopt database for a building then creates geometry for it.  Surrounding buildings are included as shading structures."
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
	  #city_db_url.setDefaultValue("http://localhost:3000")
    city_db_url.setDefaultValue("http://insight4.hpc.nrel.gov:8081/")
    args << city_db_url
    
    # project name of the building to create
    project_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("project_name", true)
    project_name.setDisplayName("Project Name")
    project_name.setDescription("Project Name.")
    args << project_name
    
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
    
    # which surrounding buildings to include
    chs = OpenStudio::StringVector.new
    chs << "None"
    chs << "ShadingOnly"
    chs << "All"
    surrounding_buildings = OpenStudio::Ruleset::OSArgument.makeChoiceArgument("surrounding_buildings", chs, true)
    surrounding_buildings.setDisplayName("Surrounding Buildings")
    surrounding_buildings.setDescription("Select which surrounding buildings to include.")
    surrounding_buildings.setDefaultValue("ShadingOnly")
    args << surrounding_buildings    

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
    all_points = OpenStudio::Point3dVector.new
    polygon.each do |p|
      lon = p[0]
      lat = p[1]
      point_3d = @origin_lat_lon.toLocalCartesian(OpenStudio::PointLatLon.new(lat, lon, 0))
      point_3d = OpenStudio::Point3d.new(point_3d.x, point_3d.y, elevation)
      floor_print << OpenStudio::getCombinedPoint(point_3d, all_points, 1.0)
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
    space_type = properties[:building_type]
    
    if space_type == "Mixed use"
      mixed_types = []
      
      if properties[:mixed_type_1] && properties[:mixed_type_1_percentage]
        mixed_types << {type: properties[:mixed_type_1], percentage: properties[:mixed_type_1_percentage]}
      end
      
      if properties[:mixed_type_2] && properties[:mixed_type_2_percentage]
        mixed_types << {type: properties[:mixed_type_2], percentage: properties[:mixed_type_2_percentage]}
      end
      
      if properties[:mixed_type_3] && properties[:mixed_type_3_percentage]
        mixed_types << {type: properties[:mixed_type_3], percentage: properties[:mixed_type_3_percentage]}
      end
      
      if properties[:mixed_type_4] && properties[:mixed_type_4_percentage]
        mixed_types << {type: properties[:mixed_type_4], percentage: properties[:mixed_type_4_percentage]}
      end
      
      if mixed_types.empty?
        @runner.registerError("'Mixed use' building type requested but 'mixed_types' argument is empty")
        return false
      end
     
      mixed_types.sort! {|x,y| x[:percentage] <=> y[:percentage]}
      
      # DLM: temp code
      space_type = mixed_types[-1][:type]
      @runner.registerWarning("'Mixed use' building type requested, using largest type '#{space_type}' for now")
    end
    
    if number_of_stories_above_ground.nil?
      number_of_stories_above_ground = number_of_stories
      number_of_stories_below_ground = 0
    else
      number_of_stories_below_ground = number_of_stories - number_of_stories_above_ground
    end
    
    # DLM: todo, set this by space type
    floor_to_floor_height = 3.6
    
    if create_method == :spaces_per_floor
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
    end
      
    spaces = []
    if create_method == :spaces_per_floor
      (-number_of_stories_below_ground+1..number_of_stories_above_ground).each do |story_number|
        new_spaces = create_spaces_per_floor(building_json, story_number, floor_to_floor_height, model)
        spaces.concat(new_spaces)
      end
    elsif create_method == :space_per_building
      spaces = create_space_per_building(building_json, -number_of_stories_below_ground*floor_to_floor_height, number_of_stories_above_ground*floor_to_floor_height, model)
    end

    return spaces
  end
  
  def divide_floor_print(floor_print, perimeter_depth)
    result = []
    
    t_inv = OpenStudio::Transformation.alignFace(floor_print)
    t = t_inv.inverse
        
    vertices = t * floor_print
    new_vertices = OpenStudio::Point3dVector.new
    n = vertices.size
    (0...n).each do |i|
      vertex_1 = nil
      vertex_2 = nil 
      vertex_3 = nil
      if (i==0)
        vertex_1 = vertices[n-1]
        vertex_2 = vertices[i] 
        vertex_3 = vertices[i+1]          
      elsif (i==(n-1))
        vertex_1 = vertices[i-1]
        vertex_2 = vertices[i] 
        vertex_3 = vertices[0]
      else
        vertex_1 = vertices[i-1]
        vertex_2 = vertices[i] 
        vertex_3 = vertices[i+1]
      end
      
      vector_1 = (vertex_2 - vertex_1)
      vector_2 = (vertex_3 - vertex_2)
      
      angle_1 = Math.atan2(vector_1.y, vector_1.x) + Math::PI/2.0
      angle_2 = Math.atan2(vector_2.y, vector_2.x) + Math::PI/2.0
      
      vector = OpenStudio::Vector3d.new(Math.cos(angle_1) + Math.cos(angle_2), Math.sin(angle_1) + Math.sin(angle_2), 0)
      vector.setLength(perimeter_depth)
      
      new_point = vertices[i] + vector
      new_vertices << new_point
    end
    
    normal = OpenStudio::getOutwardNormal(new_vertices)
    if normal.empty? || normal.get.z < 0
      @runner.registerWarning("Wrong direction for resulting normal, will not divide")
      return [floor_print]
    end
    
    self_intersects = OpenStudio::selfIntersects(OpenStudio::reverse(new_vertices), 0.01)
    if OpenStudio::VersionString.new(OpenStudio::openStudioVersion()) < OpenStudio::VersionString.new("1.12.4")
      # bug in selfIntersects method
      self_intersects = !self_intersects
    end
    
    if self_intersects
      @runner.registerWarning("Self intersecting surface result, will not divide")
      #return [floor_print]
    end
   
    # good to go
    result << t_inv * new_vertices
    
    (0...n).each do |i|
      perim_vertices = OpenStudio::Point3dVector.new
      if (i==(n-1))
        perim_vertices << vertices[i]
        perim_vertices << vertices[0] 
        perim_vertices << new_vertices[0]
        perim_vertices << new_vertices[i]
      else
        perim_vertices << vertices[i]
        perim_vertices << vertices[i+1] 
        perim_vertices << new_vertices[i+1]
        perim_vertices << new_vertices[i]
      end
      result << t_inv * perim_vertices
    end

    return result
  end 

  def create_spaces_per_floor(building_json, story_number, floor_to_floor_height, model)
  
    geometry = building_json[:geometry] 
    properties = building_json[:properties]

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
          this_floor_prints = divide_floor_print(floor_print, 4.0)
          floor_prints.concat(this_floor_prints)
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
      
      #bounding_box = space.boundingBox
      #m = OpenStudio::Matrix.new(4,4,0)
      #m[0,0] = 1
      #m[1,1] = 1
      #m[2,2] = 1
      #m[3,3] = 1
      #m[0,3] = bounding_box.minX.get
      #m[1,3] = bounding_box.minY.get
      #m[2,3] = bounding_box.minZ.get
      #space.changeTransformation(OpenStudio::Transformation.new(m))
      
      space.surfaces.each do |surface|
        if surface.surfaceType == "Wall"
          if story_number < 1
            surface.setOutsideBoundaryCondition("Ground")
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
      
      #bounding_box = space.boundingBox
      #m = OpenStudio::Matrix.new(4,4,0)
      #m[0,0] = 1
      #m[1,1] = 1
      #m[2,2] = 1
      #m[3,3] = 1
      #m[0,3] = bounding_box.minX.get
      #m[1,3] = bounding_box.minY.get
      #m[2,3] = bounding_box.minZ.get
      #space.changeTransformation(OpenStudio::Transformation.new(m))
      
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
  
  
  def get_min_lon_lat(building_json)
    min_lon = Float::MAX
    min_lat = Float::MAX
    
    # find min and max x coordinate
    multi_polygons = get_multi_polygons(building_json)
    multi_polygons.each do |multi_polygon|
      multi_polygon.each do |polygon|
        polygon.each do |point|
          min_lon = point[0] if point[0] < min_lon
          min_lat = point[1] if point[1] < min_lat
        end
          
        # subsequent polygons are holes, we do not support them
        break
      end
    end
    
    return [min_lon, min_lat]
  end
  
  def is_shadowed(building_points, other_building_points)
    all_pairs = []
    building_points.each do |building_point|
      other_building_points.each do |other_building_point|
        vector = other_building_point - building_point
        all_pairs << {:building_point => building_point, :other_building_point => other_building_point, :vector => vector, :distance => vector.length}
      end
    end
    
    all_pairs.sort! {|x, y| x[:distance] <=> y[:distance]}
    
    all_pairs.each do |pair|
      if point_is_shadowed(pair[:building_point], pair[:other_building_point])
        return true
      end
    end
    
    return false
  end
  
  
  def point_is_shadowed(building_point, other_building_point)
  
    vector = other_building_point - building_point

    height = vector.z
    distance = Math.sqrt(vector.x*vector.x + vector.y*vector.y)
    
    if distance < 1
      return true
    end
    
    hour_angle_rad = Math.atan2(-vector.x, -vector.y)
    hour_angle = OpenStudio::radToDeg(hour_angle_rad)
    lattitude_rad = OpenStudio::degToRad(@origin_lat_lon.lat)
    
    result = false
    (-24..24).each do |declination|
      
      declination_rad = OpenStudio::degToRad(declination)
      zenith_angle_rad = Math.acos(Math.sin(lattitude_rad)*Math.sin(declination_rad) + Math.cos(lattitude_rad)*Math.cos(declination_rad)*Math.cos(hour_angle_rad))
      zenith_angle = OpenStudio::radToDeg(zenith_angle_rad)
      elevation_angle = 90-zenith_angle
        
      apparent_angle_rad = Math.atan2(height, distance)
      apparent_angle = OpenStudio::radToDeg(apparent_angle_rad)
    
      #puts "declination is #{declination}.  Other building is #{distance} m away and #{height} m high, hour_angle is #{hour_angle}, apparent angle is #{apparent_angle}, zenith_angle is #{zenith_angle}, elevation_angle is #{elevation_angle}"
      
      if (elevation_angle > 0 && elevation_angle < apparent_angle)
        result = true
        break
      end
    end
    
    #puts "lattitude = #{@origin_lat_lon.lat}, vector = #{vector}, distance = #{distance}, height = #{height}, shadowed = #{result}"
    
    return result
  end
  
  # get the project from the database
  def get_project(project_name)

    params = {}
    params[:name] = project_name

    http = Net::HTTP.new(@city_db_url, @port)
    http.read_timeout = 1000
    if @city_db_is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Post.new("/api/project_search.json")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.body = JSON.generate(params)
    
    # DLM: todo, get these from environment variables or as measure inputs?
    request.basic_auth("test@nrel.gov", "testing123")
  
    response = http.request(request)
    if  response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      return {}
    end
    
    return JSON.parse(response.body, :symbolize_names => true)
  end
  
  # get the feature collection from the database
  def get_feature_collection(params)
    
    http = Net::HTTP.new(@city_db_url, @port)
    http.read_timeout = 1000
    if @city_db_is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    request = Net::HTTP::Post.new("/api/search.json")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.body = JSON.generate(params)
    
    # DLM: todo, get these from environment variables or as measure inputs?
    request.basic_auth("test@nrel.gov", "testing123")
  
    response = http.request(request)
    if  response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      return {}
    end
    
    return JSON.parse(response.body, :symbolize_names => true)
  end
  
  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
     
    # assign the user inputs to variables
    city_db_url = runner.getStringArgumentValue("city_db_url", user_arguments)
    project_name = runner.getStringArgumentValue("project_name", user_arguments)
    source_id = runner.getStringArgumentValue("source_id", user_arguments)
    source_name = runner.getStringArgumentValue("source_name", user_arguments)
    surrounding_buildings = runner.getStringArgumentValue("surrounding_buildings", user_arguments)
    
    # instance variables
    @runner = runner
    @origin_lat_lon = nil

    # @port = 80
    # if md = /http:\/\/(.*):(\d+)/.match(city_db_url)
    #   @city_db_url = md[1]
    #   @port = md[2]
    # elsif /http:\/\/([^:\/]*)/.match(city_db_url)
    #   @city_db_url = md[1]
    # end

    uri = URI.parse(city_db_url)
    @city_db_url = uri.host
    @port = uri.port
    @city_db_is_https = uri.scheme == 'https' ? true : false

    project = get_project(project_name)
    
    if project.nil? || project.empty?
      @runner.registerError("Could not find project '#{project_name}")
      return false
    end
    project_id = project.first[:id]
    
    params = {}
    params[:commit] = 'Search'
    params[:project_id] = project_id
    params[:source_id] = source_id
    params[:source_name] = source_name
    params[:feature_types] = ['Building']
    
    feature_collection = get_feature_collection(params)

    if feature_collection[:features].nil?
      @runner.registerError("No features found in #{feature_collection}")
      return false
    elsif feature_collection[:features].empty?
      @runner.registerError("No features found in #{feature_collection}")
      return false
    elsif feature_collection[:features].size > 1
      @runner.registerError("Multiple features found in #{feature_collection}")
      return false
    end
    
    building_json = feature_collection[:features][0]
    
    if building_json[:geometry].nil?
      @runner.registerError("No geometry found in #{building_json}")
      return false
    end
    
    geometry_type = building_json[:geometry][:type]
    if geometry_type == "Polygon"
      # ok
    elsif geometry_type == "MultiPolygon"
      # ok
    else
      @runner.registerError("Unknown geometry type #{geometry_type}")
      return false
    end

    # find min and max x coordinate
    min_lon_lat = get_min_lon_lat(building_json)
    min_lon = min_lon_lat[0]
    min_lat = min_lon_lat[1]

    if min_lon == Float::MAX || min_lat == Float::MAX 
      @runner.registerError("Could not determine min_lat and min_lon")
      return false
    else
      @runner.registerInfo("Min_lat = #{min_lat}, min_lon = #{min_lon}")
    end

    @origin_lat_lon = OpenStudio::PointLatLon.new(min_lat, min_lon, 0)
    
    site = model.getSite
    site.setLatitude(@origin_lat_lon.lat)
    site.setLongitude(@origin_lat_lon.lon)
    
    if building_json[:properties][:surface_elevation]
      surface_elevation = building_json[:properties][:surface_elevation].to_f
      site.setElevation(surface_elevation)
    end
    
    # make requested building
    spaces = create_building(building_json, :spaces_per_floor, model)
    if spaces.nil? || spaces.empty?
      @runner.registerError("Failed to create spaces for building #{source_id}")
      return false
    end
    
    # get first floor footprint points
    building_points = []
    multi_polygons = get_multi_polygons(building_json)
    multi_polygons.each do |multi_polygon|
      multi_polygon.each do |polygon|
        elevation = 0
        floor_print = floor_print_from_polygon(polygon, elevation)
        floor_print.each do |point|
          building_points << point
        end
        
        # subsequent polygons are holes, we do not support them
        break
      end
    end
      
    # nearby buildings to conver to shading
    convert_to_shades = []
    
    if surrounding_buildings == "None"
      # no-op
    else

      # query database for nearby buildings
      params = {}
      params[:commit] = 'Proximity Search'
      params[:project_id] = project_id
      params[:building_id] = building_json[:properties][:id]
      params[:distance] = 100
      params[:proximity_feature_types] = ['Building']

      feature_collection = get_feature_collection(params)
      
      if feature_collection[:features].nil?
        @runner.registerError("No features found in #{feature_collection}")
        return false
      end

      @runner.registerInfo("#{feature_collection[:features].size} nearby buildings found")
      
      count = 0
      feature_collection[:features].each do |other_building|
      
        other_source_id = other_building[:properties][:source_id]
        next if other_source_id == source_id
      
        if surrounding_buildings == "ShadingOnly"
        
          # check if any building point is shaded by any other building point
          surface_elevation	= other_building[:properties][:surface_elevation]
          roof_elevation	= other_building[:properties][:roof_elevation]
          number_of_stories = other_building[:properties][:number_of_stories]
          number_of_stories_above_ground = other_building[:properties][:number_of_stories_above_ground]
          floor_to_floor_height = other_building[:properties][:floor_to_floor_height]
          
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
          
          other_height = number_of_stories_above_ground * floor_to_floor_height
          
          # get first floor footprint points
          other_building_points = []
          multi_polygons = get_multi_polygons(other_building)
          multi_polygons.each do |multi_polygon|
            multi_polygon.each do |polygon|
              floor_print = floor_print_from_polygon(polygon, other_height)
              floor_print.each do |point|
                other_building_points << point
              end
              
              # subsequent polygons are holes, we do not support them
              break
            end
          end
        
          shadowed = is_shadowed(building_points, other_building_points)
          if !shadowed
            next
          end
        end
       
        other_spaces = create_building(other_building, :space_per_building, model)
        if other_spaces.nil? || other_spaces.empty?
          @runner.registerError("Failed to create spaces for other building #{other_source_id}")
          return false
        end
        
        convert_to_shades.concat(other_spaces)
      end
    end
    
    # intersect surfaces in this building with others
    @runner.registerInfo("Intersecting surfaces")
    spaces.each do |space|
      convert_to_shades.each do |other_space|
        space.intersectSurfaces(other_space)
      end
    end

    # match surfaces
    @runner.registerInfo("Matching surfaces")
    all_spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      all_spaces << space
    end
    OpenStudio::Model.matchSurfaces(all_spaces)
    
    # make windows
    window_to_wall_ratio = building_json[:properties][:window_to_wall_ratio]
    
    if window_to_wall_ratio.nil?
      window_to_wall_ratio = 0.3
    end

    spaces.each do |space|
      space.surfaces.each do |surface|
        if surface.surfaceType == "Wall" && surface.outsideBoundaryCondition == "Outdoors"
          surface.setWindowToWallRatio(window_to_wall_ratio)
        end
      end
    end
    
    # change adjacent surfaces to adiabatic
    @runner.registerInfo("Changing adjacent surfaces to adiabatic")
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
    
    # convert other buildings to shading surfaces
    convert_to_shades.each do |space|
      convert_to_shading_surface_group(space)
    end

    return true

  end
  
end

# register the measure to be used by the application
UrbanGeometryCreation.new.registerWithApplication
