# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'json'

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
    
    # path to the city.json file
    city_json_path = OpenStudio::Ruleset::OSArgument.makeStringArgument("city_json_path", true)
    city_json_path.setDisplayName("City JSON Path")
    city_json_path.setDescription("Path to city.json.")
	city_json_path.setDefaultValue("../../../../openstudio-urban-measures/city.json")
    args << city_json_path
    
    # the id of the building to create
    building_id = OpenStudio::Ruleset::OSArgument.makeStringArgument("building_id", true)
    building_id.setDisplayName("Building ID")
    building_id.setDescription("Building ID to generate, use '*All*' to generate all.")
	building_id.setDefaultValue("142484")
    args << building_id

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
  
  def floor_print_from_polygon(building, polygon, elevation)
    if !polygon[:holes].empty?
      #@runner.registerWarning("Cannot create footprint for building #{building[:id]}, contains inner polygon")
      #return []
      @runner.registerWarning("Ignoring inner polygon for footprint for building #{building[:id]}")
      return nil
    end
    
    floor_print = OpenStudio::Point3dVector.new
    polygon[:points].each do |p|
      floor_print << OpenStudio::Point3d.new(p[:x] - @min_x, p[:y] - @min_y, elevation)
    end
  
    if floor_print.size < 3
      @runner.registerWarning("Cannot create footprint for building #{building[:id]}, fewer than 3 points")
      return nil
    end
  
    floor_print = OpenStudio::removeCollinear(floor_print)
    normal = OpenStudio::getOutwardNormal(floor_print)
    if normal.empty?
      @runner.registerWarning("Cannot create footprint for building #{building[:id]}, cannot compute outward normal")
      return nil
    elsif normal.get.z > 0
      floor_print = OpenStudio::reverse(floor_print)
      @runner.registerWarning("Reversing floor print for building #{building[:id]}")
    end
    
    return floor_print
  end

  def create_building(building, is_primary, create_method, model)
    
    surface_elevation	= building[:surface_elevation]
    roof_elevation	= building[:roof_elevation]
    number_of_stories = building[:number_of_stories]
    number_of_stories_above_ground = building[:number_of_stories_above_ground]
    number_of_stories_below_ground = building[:number_of_stories_below_ground]
    number_of_residential_units = building[:number_of_residential_units]
    
    if is_primary
      # get the building use and fix any issues
      bldg_use = building[:space_type]
      building_space_type = create_space_type(bldg_use, bldg_use, model)
      model.getBuilding.setSpaceType(building_space_type)
      #model.getBuilding.setNominalFloortoFloorHeight(floor_to_floor_height)
      model.getBuilding.setStandardsNumberOfStories(number_of_stories)

      if number_of_stories_above_ground
        model.getBuilding.setStandardsNumberOfAboveGroundStories(number_of_stories_above_ground)
      end
      if number_of_residential_units
        model.getBuilding.setStandardsNumberOfLivingUnits(number_of_residential_units)
      end
      #model.getBuilding.setNominalFloortoCeilingHeight
      model.getBuilding.setStandardsBuildingType(bldg_use)
      model.getBuilding.setRelocatable(false)
    end
    
    spaces = []
    if create_method == :space_per_floor
      building[:stories].each do |story|
        new_spaces = create_space_per_floor(building, story, model)
        spaces.concat(new_spaces)
      end
    elsif create_method == :space_per_building
      spaces = create_space_per_building(building, model)
    end

    return spaces
  end

  def create_space_per_floor(building, story, model)
  
    result = []
    story[:footprint][:polygons].each do |polygon|
      next if polygon[:coordinate_system] != "Local Cartesian"
      
      floor_print = floor_print_from_polygon(building, polygon, story[:elevation])
      next if !floor_print
      
      floor_to_floor_height = story[:floor_to_floor_height]
      
      space = OpenStudio::Model::Space.fromFloorPrint(floor_print, floor_to_floor_height, model)
      if space.empty?
        @runner.registerWarning("Cannot create story #{story[:name]} for building #{building[:id]}")
        next
      end
      space = space.get
      
      story_space_type = create_space_type(building[:space_type], story[:space_type], model)
      
      space.setName(story[:name] + " Space")
      space.setSpaceType(story_space_type)
      
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
          if story[:story_number] < 1
            surface.setOutsideBoundaryCondition("Ground")
          else
            surface.setWindowToWallRatio(story[:window_to_wall_ratio])
          end
        end
      end
        
      building_story = OpenStudio::Model::BuildingStory.new(model)
      building_story.setName(story[:name])
      space.setBuildingStory(building_story)
      
      thermal_zone = OpenStudio::Model::ThermalZone.new(model)
      thermal_zone.setName(story[:name] + " ThermalZone")
      space.setThermalZone(thermal_zone)
      
      result << space 
    end
    
    return result
  end
  
  def create_space_per_building(building, model)
  
    min_elevation = nil
    total_height = 0
    building[:stories].each do |story|
      if min_elevation
        min_elevation = [min_elevation, story[:elevation]].min
      else
        min_elevation = story[:elevation]
      end
      total_height += story[:floor_to_floor_height]
    end
    
    result = []
    building[:footprint][:polygons].each do |polygon|
      next if polygon[:coordinate_system] != "Local Cartesian"
    
      floor_print = floor_print_from_polygon(building, polygon, min_elevation)
      next if !floor_print

      space = OpenStudio::Model::Space.fromFloorPrint(floor_print, total_height, model)
      if space.empty?
        @runner.registerWarning("Cannot create geometry for building #{building[:id]}")
        next
      end
      space = space.get
      
      building_space_type = create_space_type(building[:space_type], building[:space_type], model)
      
      space.setName("Building #{building[:id]} Space")
      space.setSpaceType(building_space_type)
      
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
      
      thermal_zone = OpenStudio::Model::ThermalZone.new(model)
      thermal_zone.setName("Building #{building[:id]} ThermalZone")
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

  def add_windows(model)
    model.getSurfaces.each do |surface|
      if surface.surfaceType == 'Wall' and surface.outsideBoundaryCondition == 'Outdoors'
        surface.setWindowToWallRatio(0.3)
      end
    end
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    city_json_path = runner.getStringArgumentValue("city_json_path", user_arguments)
    building_id = runner.getStringArgumentValue("building_id", user_arguments)
    
    # instance variables
    @runner = runner
    @min_x = Float::MAX 
    @min_y = Float::MAX 
    
    # read json
    city = {}
    File.open(city_json_path, 'r') do |file|
      city = JSON.parse(file.read, {:symbolize_names => true})
    end
    
    buildings = city[:buildings]
    if buildings.length == 0
      runner.registerError("No buildings found in #{city_json_path}")
      return false
    end
    runner.registerInfo("#{buildings.length} buildings found")
    
    # find min and max x coordinate
    buildings.each do |building|
      building[:footprint][:polygons].each do |polygon|
        next if polygon[:coordinate_system] != "Local Cartesian"
        polygon[:points].each do |point|
          @min_x = point[:x] if point[:x] < @min_x
          @min_y = point[:y] if point[:y] < @min_y
        end
      end
    end
    runner.registerInfo("min_x = #{@min_x}, min_y = #{@min_y}")
   
    # buildings to convert to shading surfaces later
    convert_to_shades = []
    
    # creating buildings
    if (building_id == "*All*")
    
      num_bldgs = 0
      max_bldgs = Float::INFINITY
      #max_bldgs = 10
      
      # make all buildings
      buildings.each do |building|
        if num_bldgs >= max_bldgs 
          next
        end
        #if !/Commercial/.match(building[:bldg_use])
        #  next
        #end
        
        is_primary = false
        spaces = create_building(building, is_primary, :space_per_building, model)
        if !spaces.nil? && !spaces.empty?
          num_bldgs += 1
        end
        
        GC.start
      end
      
      runner.registerInfo("Created #{num_bldgs} buildings")
      
    else
      
      # make requested building
      building = buildings.find{|b| b[:id] == building_id}
      if building.nil?
        runner.registerError("Cannot find building #{building_id}")
        return false
      end
      
      is_primary = true
      spaces = create_building(building, is_primary, :space_per_floor, model)
      if spaces.nil? || spaces.empty?
        runner.registerError("Failed to create spaces for building #{building_id}")
        return false
      end
      
      other_building_ids = building[:intersecting_building_ids].concat(building[:surrounding_building_ids]).uniq
      other_building_ids.each do |other_building_id|
        other_building = buildings.find{|b| b[:id] == other_building_id}
              
        if other_building.nil?
          runner.registerError("Cannot find other building #{other_building_id}")
          return false
        end
        
        is_primary = false
        spaces = create_building(other_building, is_primary, :space_per_building, model)
        if spaces.nil? || spaces.empty?
          runner.registerError("Failed to create spaces for other building #{other_building_id}")
          return false
        end
        
        convert_to_shades.concat(spaces)
      end
      
    end

    # match surfaces
    runner.registerInfo("matching surfaces")
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    runner.registerInfo("changing adjacent surfaces to adiabatic")
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
