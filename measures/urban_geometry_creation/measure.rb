######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

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
    project_id = OpenStudio::Ruleset::OSArgument.makeStringArgument("project_id", true)
    project_id.setDisplayName("Project ID")
    project_id.setDescription("Project ID.")
    args << project_id
    
    # source id of the building to create
    feature_id = OpenStudio::Ruleset::OSArgument.makeStringArgument("feature_id", true)
    feature_id.setDisplayName("Feature ID")
    feature_id.setDescription("Feature ID.")
    args << feature_id
    
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
    number_of_stories = properties[:number_of_stories]
    number_of_stories_above_ground = properties[:number_of_stories_above_ground]
    number_of_stories_below_ground = properties[:number_of_stories_below_ground]
    number_of_residential_units = properties[:number_of_residential_units]
    maximum_roof_height = properties[:maximum_roof_height]
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
        return nil
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
    
    floor_to_floor_height = 3
    if number_of_stories_above_ground && number_of_stories_above_ground > 0 && maximum_roof_height
      floor_to_floor_height = maximum_roof_height / number_of_stories_above_ground
      floor_to_floor_height = OpenStudio::convert(floor_to_floor_height, 'ft', 'm').get
    end
    
    if create_method == :space_per_floor
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
    name = properties[:name]
    
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
          @runner.registerWarning("Cannot get floor print for building '#{name}'")
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
      space.setName("Building #{name} Space")
      
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
      thermal_zone.setName("Building #{name} ThermalZone")
      space.setThermalZone(thermal_zone)
      
      result << space 
    end
    
    return result
  end
  
  def create_other_buildings(building_json, surrounding_buildings, model)
    
    project_id = building_json[:properties][:project_id]
    feature_id = building_json[:properties][:id]
    
    # nearby buildings to conver to shading
    convert_to_shades = []

    # query database for nearby buildings
    params = {}
    params[:commit] = 'Proximity Search'
    params[:project_id] = project_id
    params[:feature_id] = feature_id
    params[:distance] = 100
    params[:proximity_feature_types] = ['Building']

    feature_collection = get_feature_collection(params)
    
    if feature_collection[:features].nil?
      @runner.registerWarning("No features found in #{feature_collection}")
      return []
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
    
    @runner.registerInfo("#{feature_collection[:features].size} nearby buildings found")
    
    count = 0
    feature_collection[:features].each do |other_building|
    
      other_id = other_building[:properties][:id]
      next if other_id == feature_id
    
      if surrounding_buildings == "ShadingOnly"
      
        # check if any building point is shaded by any other building point
        roof_elevation	= other_building[:properties][:roof_elevation]
        number_of_stories = other_building[:properties][:number_of_stories]
        number_of_stories_above_ground = other_building[:properties][:number_of_stories_above_ground]
        maximum_roof_height = properties[:maximum_roof_height]
        
        if number_of_stories_above_ground.nil?
          if number_of_stories_below_ground.nil?
            number_of_stories_above_ground = number_of_stories
            number_of_stories_below_ground = 0
          else
            number_of_stories_above_ground = number_of_stories - number_of_stories_above_ground
          end
        end
        
        floor_to_floor_height = 3
        if number_of_stories_above_ground && number_of_stories_above_ground > 0 && maximum_roof_height
          floor_to_floor_height = maximum_roof_height / number_of_stories_above_ground
          floor_to_floor_height = OpenStudio::convert(floor_to_floor_height, 'ft', 'm')
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
        @runner.registerWarning("Failed to create spaces for other building '#{name}'")
      end
      
      convert_to_shades.concat(other_spaces)
    end
    
    return convert_to_shades

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
  
  def create_photovoltaics(feature_json, height, model)
   
    properties = feature_json[:properties]
    feature_id = properties[:properties]
    name = properties[:name]

    floor_prints = []
    multi_polygons = get_multi_polygons(feature_json)
    multi_polygons.each do |multi_polygon|
      
      if multi_polygon.size > 1
        @runner.registerWarning("Ignoring holes in polygon")
      end
      
      multi_polygon.each do |polygon|
        floor_print = floor_print_from_polygon(polygon, height)
        if floor_print
          floor_prints << OpenStudio::reverse(floor_print)
        else 
          @runner.registerWarning("Cannot create footprint for '#{name}'")
        end
          
        # subsequent polygons are holes, we do not support them
        break
      end
    end
    
    shading_surfaces = []
    floor_prints.each do |floor_print|
      shading_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      
      shading_surface = OpenStudio::Model::ShadingSurface.new(floor_print, model)
      shading_surface.setShadingSurfaceGroup(shading_group)
      shading_surface.setName("Photovoltaic Panel")
     
      shading_surfaces << shading_surface 
    end
    
    # create the inverter
    inverter = OpenStudio::Model::ElectricLoadCenterInverterSimple.new(model)
    inverter.setInverterEfficiency(0.95)

    # create the distribution system
    elcd = OpenStudio::Model::ElectricLoadCenterDistribution.new(model)
    elcd.setInverter(inverter)
    
    shading_surfaces.each do |shading_surface|
      panel = OpenStudio::Model::GeneratorPhotovoltaic::simple(model)
      panel.setSurface(shading_surface)
      performance = panel.photovoltaicPerformance.to_PhotovoltaicPerformanceSimple.get
      performance.setFractionOfSurfaceAreaWithActiveSolarCells(1.0)
      performance.setFixedEfficiency(0.3)
      
      elcd.addGenerator(panel)
    end
    
    return shading_surfaces
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
  def get_project(project_id)

    http = Net::HTTP.new(@city_db_url, @port)
    http.read_timeout = 1000
    if @city_db_is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    
    request = Net::HTTP::Get.new("/projects/#{project_id}.json")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])
  
    response = http.request(request)
    if  response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      @result = false
      return {}
    end
    
    result = JSON.parse(response.body, :symbolize_names => true)
    return result
  end
  
  # get the feature from the database
  def get_feature(project_id, feature_id)
    
    http = Net::HTTP.new(@city_db_url, @port)
    http.read_timeout = 1000
    if @city_db_is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Get.new("/api/feature.json?project_id=#{project_id}&feature_id=#{feature_id}")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])
    @runner.registerInfo("/api/feature.json?project_id=#{project_id}&feature_id=#{feature_id}")
    response = http.request(request)
    if  response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      @result = false
      return {}
    end
    
    result = JSON.parse(response.body, :symbolize_names => true)
    return result
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
    request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])
  
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
    project_id = runner.getStringArgumentValue("project_id", user_arguments)
    feature_id = runner.getStringArgumentValue("feature_id", user_arguments)
    surrounding_buildings = runner.getStringArgumentValue("surrounding_buildings", user_arguments)
    
    # pull information from the previous model 
    #model.save('initial.osm', true)
    
    default_construction_set = model.getBuilding.defaultConstructionSet
    if !default_construction_set.is_initialized
      runner.registerInfo("Starting model does not have a default construction set, creating new one")
      default_construction_set = OpenStudio::Model::DefaultConstructionSet.new(model)
    else
      default_construction_set = default_construction_set.get
    end
      
    stories = []
    model.getBuildingStorys.each { |story| stories << story }
    stories.sort! { |x,y| x.nominalZCoordinate.to_s.to_f <=> y.nominalZCoordinate.to_s.to_f }

    space_types = []
    stories.each_index do |i|
      space_type = nil
      space = stories[i].spaces.first
      if space && space.spaceType.is_initialized
        space_type = space.spaceType.get
      else  
        space_type = OpenStudio::Model::SpaceType.new(model)
        runner.registerInfo("Story #{i} does not have a space type, creating new one")
      end
      space_types[i] = space_type
    end
    
    # delete the previous building
    model.getBuilding.remove
    
    # create new building and transfer default construction set
    model.getBuilding.setDefaultConstructionSet(default_construction_set)
    
    # instance variables
    @runner = runner
    @origin_lat_lon = nil

    uri = URI.parse(city_db_url)
    @city_db_url = uri.host
    @port = uri.port
    @city_db_is_https = uri.scheme == 'https' ? true : false

    feature = get_feature(project_id, feature_id)
    if feature.nil? || feature.empty?
      @runner.registerError("Feature '#{feature_id}' could not be found")
      return false
    end
    
    if feature[:geometry].nil?
      @runner.registerError("No geometry found in '#{feature}'")
      return false
    end
    
    if feature[:properties].nil?
      @runner.registerError("No properties found in '#{feature}'")
      return false
    end
    
    name = feature[:properties][:name]
    model.getBuilding.setName(name)

    geometry_type = feature[:geometry][:type]
    if geometry_type == "Polygon"
      # ok
    elsif geometry_type == "MultiPolygon"
      # ok
    else
      @runner.registerError("Unknown geometry type '#{geometry_type}'")
      return false
    end

    # find min and max x coordinate
    min_lon_lat = get_min_lon_lat(feature)
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
    
    if feature[:properties][:surface_elevation]
      surface_elevation = feature[:properties][:surface_elevation].to_f
      surface_elevation = OpenStudio::convert(surface_elevation, 'ft', 'm').get
      site.setElevation(surface_elevation)
    end
    
    feature_type = feature[:properties][:type]
    
    if feature_type == 'Building'
    
      # make requested building
      spaces = create_building(feature, :space_per_floor, model)
      if spaces.nil? 
        @runner.registerError("Failed to create spaces for building '#{name}'")
        return false
      end
      
      # DLM: temp hack
      building_type = feature[:properties][:building_type]
      if building_type == 'Vacant'
        max_z = 0
        spaces.each do |space|
          bb = space.boundingBox
          max_z = [max_z, bb.maxZ.get].max
        end
        shading_surfaces = create_photovoltaics(feature, max_z + 1, model)
      end
      
      # make other buildings to convert to shading
      convert_to_shades = []
      if surrounding_buildings == "None"
        # no-op
      else
        convert_to_shades = create_other_buildings(feature, surrounding_buildings, model)
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
      window_to_wall_ratio = feature[:properties][:window_to_wall_ratio]
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
          else
            @runner.registerError("Surface '#{surface.nameString}' does not have a construction")
            #model.save('error.osm', true)
            return false
          end
          surface.setOutsideBoundaryCondition('Adiabatic')
          
          adjacent_surface_construction = adjacent_surface.get.construction
          if !adjacent_surface_construction.empty?
            adjacent_surface.get.setConstruction(adjacent_surface_construction.get)
          else
            @runner.registerError("Surface '#{adjacent_surface.get.nameString}' does not have a construction")
            #model.save('error.osm', true)
            return false
          end
          adjacent_surface.get.setOutsideBoundaryCondition('Adiabatic')
        end
      end
    
      # convert other buildings to shading surfaces
      convert_to_shades.each do |space|
        convert_to_shading_surface_group(space)
      end

    elsif feature_type == 'District System'
    
      district_system_type = feature[:properties][:district_system_type]
      
      if district_system_type == 'Community Photovoltaic'
        shading_surfaces = create_photovoltaics(feature, 0, model)
      end

    else
      @runner.registerError("Unknown feature type '#{feature_type}'")
      return false
    end
    
    # transfer data from previous model
    stories = []
    model.getBuildingStorys.each { |story| stories << story }
    stories.sort! { |x,y| x.nominalZCoordinate.to_s.to_f <=> y.nominalZCoordinate.to_s.to_f }

    stories.each_index do |i|
      space_type = space_types[i]
      next if space_type.nil?
      
      stories[i].spaces.each do |space|
        space.setSpaceType(space_type)
      end
    end
    

    return true

  end
  
end

# register the measure to be used by the application
UrbanGeometryCreation.new.registerWithApplication
