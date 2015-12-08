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
    #city_json_path = OpenStudio::Ruleset::OSArgument.makePathArgument("city_json_path", true, "json", true)
    city_json_path = OpenStudio::Ruleset::OSArgument.makeStringArgument("city_json_path", true)
    city_json_path.setDisplayName("City JSON Path")
    city_json_path.setDescription("Path to city.json.")
	city_json_path.setDefaultValue("../../../../lib/city_data/city.json")
    args << city_json_path
    
    # the id of the building to create
    building_id = OpenStudio::Ruleset::OSArgument.makeStringArgument("building_id", true)
    building_id.setDisplayName("Building ID")
    building_id.setDescription("Building ID to generate, use '*All*' to generate all.")
	building_id.setDefaultValue("142484")
    args << building_id

    return args
  end
  
  def point_to_xy(point)
    md = /\[(.*),(.*)\]/.match(point[@point_symbol])
    result = [md[1].to_f, md[2].to_f]
    if @point_symbol == :point_xy_2913
      result[0] = 0.3048*result[0]
      result[1] = 0.3048*result[1]
    end
    return result
  end
  
  def fix_space_use(space_use, building)
    units_res = building[:units_res]
    bldg_footprint_m2 = building[:bldg_footprint_m2].to_f
    
    if space_use.nil?
      zone = building[:zone]
      if zone.nil?
        if bldg_footprint_m2 > 300 
          space_use = "Commercial Office"
        else
          space_use = "Single Family Residential"
        end
      elsif /R/.match(zone)
        if bldg_footprint_m2 > 300 
          space_use = "Multi Family Residential"
        else
          space_use = "Single Family Residential"
        end
      else
        space_use = "Commercial Office"
      end
    end
    
    cbecs_space_use = nil
    if space_use == "Multi Family Residential"
      if units_res
        if units_res.to_i <= 4
          cbecs_space_use= "Multifamily (2 to 4 units)"
        else
          cbecs_space_use= "Multifamily (5 or more units)"
        end
      else
        if bldg_footprint_m2 > 800
          cbecs_space_use= "Multifamily (5 or more units)"
        else
          cbecs_space_use= "Multifamily (2 to 4 units)"
        end
      end
    elsif space_use == "Single Family Residential"
      cbecs_space_use= "Single-Family"
    elsif space_use == "Commercial Grocery"
      cbecs_space_use = "Food sales"
    elsif space_use == "Commercial Hotel"
      cbecs_space_use = "Lodging"
    elsif space_use == "Commercial Office"
      cbecs_space_use = "Office"
    elsif space_use == "Commercial Restaurant"
      cbecs_space_use = "Food service"
    elsif space_use == "Commercial Retail"
      cbecs_space_use = "Retail other than mall"
    elsif space_use == "Industrial"   
      cbecs_space_use = "Nonrefrigerated warehouse"
    elsif space_use == "Institutional"    
      cbecs_space_use = "Office"      
    elsif space_use == "Institutional Religious"    
      cbecs_space_use = "Religious worship"
    elsif space_use == "Parking"    
      cbecs_space_use = "Other"
    elsif space_use == "Vacant"    
      cbecs_space_use = "Vacant"
    else
      raise "Unknown space_use '#{space_use}'"
    end
    
    return cbecs_space_use
  end
  
  def create_space_type(bldg_use, space_use, model)
    
    # check if we already have this space type
    model.getSpaceTypes.each do |s|
      if s.name.get == space_use
        return s
      end
    end
    
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setName(space_use)
    space_type.setStandardsBuildingType(bldg_use)
    space_type.setStandardsSpaceType(space_use)
      
    return space_type
  end

  def create_building(fid, building, create_method, model)
    
    surf_elev_m	= building[:surf_elev_m].to_f
    roof_elev_m	= building[:roof_elev_m].to_f
    num_story = building[:num_story].to_i
    floor_to_floor_height = 3.65 # assume 12 ft
    
    if surf_elev_m == 0 and roof_elev_m == 0
      surf_elev_m = nil
      roof_elev_m = nil
    end
    
    if roof_elev_m == 0 and roof_elev_m < surf_elev_m
      roof_elev_m = nil
    end
    
    if num_story == 0
      num_story = nil 
    end
    
    if surf_elev_m and roof_elev_m and num_story
      floor_to_floor_height = (roof_elev_m - surf_elev_m) / num_story
    elsif surf_elev_m and roof_elev_m.nil? and num_story
      roof_elev_m = surf_elev_m + num_story*floor_to_floor_height
    elsif surf_elev_m and roof_elev_m and num_story.nil?
      num_story = ((roof_elev_m-surf_elev_m) / floor_to_floor_height).to_i
      num_story = 1 if num_story < 1 
    elsif surf_elev_m.nil? and roof_elev_m and num_story
      surf_elev_m = roof_elev_m - num_story*floor_to_floor_height
    elsif surf_elev_m.nil? and roof_elev_m.nil? and num_story
      surf_elev_m = 0
      roof_elev_m = num_story*floor_to_floor_height
    else
      @runner.registerWarning("Insufficient elevation information for building #{fid}")
      return []
    end
    
    if floor_to_floor_height < 2.5 # 8 ft
      @runner.registerWarning("Floor to floor height is smaller than expected for building #{fid}, surf_elev_m = #{surf_elev_m}, roof_elev_m = #{roof_elev_m}, num_story = #{num_story}, floor_to_floor_height = #{floor_to_floor_height}")
    end
    
    # zero out surface elevation here if desired
    surf_elev_m = 0

    floor_print = OpenStudio::Point3dVector.new
    building[:points].each do |point|
      if point[:multi_part_plygn_index] != 1
        @runner.registerWarning("Cannot create footprint for building #{fid}, contains multi polygon")
        return []
      end
      if point[:plygn_index] != 1
        #@runner.registerWarning("Cannot create footprint for building #{fid}, contains inner polygon")
        #return []
        @runner.registerWarning("Ignoring inner polygon for footprint for building #{fid}")
        next
      end
      
      val = point_to_xy(point)
      floor_print << OpenStudio::Point3d.new(val[0].to_f - @min_x, val[1].to_f - @min_y, surf_elev_m)
    end
    
    if floor_print.size < 3
      @runner.registerWarning("Cannot create footprint for building #{fid}, fewer than 3 points")
      return []
    end
    
    floor_print = OpenStudio::removeCollinear(floor_print)
    normal = OpenStudio::getOutwardNormal(floor_print)
    if normal.empty?
      @runner.registerWarning("Cannot create footprint for building #{fid}, cannot compute outward normal")
      return []
    elsif normal.get.z > 0
      floor_print = OpenStudio::reverse(floor_print)
      @runner.registerWarning("Reversing floor print for building #{fid}")
    end
    
    # get the building use and fix any issues
    bldg_use = fix_space_use(building[:bldg_use], building)
    building_space_type = create_space_type(bldg_use, bldg_use, model)
    model.getBuilding.setSpaceType(building_space_type)
    #model.getBuilding.setNominalFloortoFloorHeight
    #model.getBuilding.setStandardsNumberOfStories
    #model.getBuilding.setStandardsNumberOfAboveGroundStories
    #model.getBuilding.setStandardsNumberOfLivingUnits
    #model.getBuilding.setNominalFloortoCeilingHeight
    model.getBuilding.setStandardsBuildingType(bldg_use)
    model.getBuilding.setRelocatable(false)
    
    # TODO: get space type by floor for mixed use
    space_types = []
    (1..num_story).each do |floor|
      space_types << create_space_type(bldg_use, bldg_use, model)
    end
      
    if create_method == :space_per_building
      return create_space_per_building(fid, floor_print, surf_elev_m, floor_to_floor_height, num_story, space_types, model)
    elsif create_method == :space_per_floor
      return create_space_per_floor(fid, floor_print, surf_elev_m, floor_to_floor_height, num_story, space_types, model)
    end
    
    return nil
  end
  
  def create_space_per_building(fid, floor_print, surf_elev_m, floor_to_floor_height, num_story, space_types, model)

    space = OpenStudio::Model::Space.fromFloorPrint(floor_print, floor_to_floor_height*num_story, model)
    if space.empty?
      @runner.registerWarning("Cannot create footprint for building #{fid}")
      return []
    end
    
    name = "Bldg #{fid}"
    space.get.setName(name)
    
    thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    thermal_zone.setName(name + " ThermalZone")
    space.get.setThermalZone(thermal_zone)
    
    # no floor by floor space type in create_space_per_building
    
    if num_story > 1
      area = space.get.floorArea * num_story
      #thermal_zone.setFloorArea(area) # DLM: doesn't work 
      thermal_zone.setDouble(5,area) 
      
      volume = area*floor_to_floor_height*num_story
      thermal_zone.setVolume(volume)
    end
    
    return [space.get]
  end

  def create_space_per_floor(fid, floor_print, surf_elev_m, floor_to_floor_height, num_story, space_types, model)
    
    space = OpenStudio::Model::Space.fromFloorPrint(floor_print, floor_to_floor_height, model)
    if space.empty?
      @runner.registerWarning("Cannot create footprint for building #{fid}")
      return []
    end
    
    name = "Bldg #{fid} Floor 1"
    space.get.setName(name)
    space.get.setSpaceType(space_types[0])
    
    thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    thermal_zone.setName(name + " ThermalZone")
    space.get.setThermalZone(thermal_zone)
    
    result = [space.get]
    
    # create higher floors
    (2..num_story).each do |floor|
      name = "Bldg #{fid} Floor #{floor}"
      
      new_space = space.get.clone(model).to_Space.get
      new_space.setZOrigin((floor-1) * floor_to_floor_height)
      new_space.setName(name)
      space.get.setSpaceType(space_types[floor-1])
      
      thermal_zone = OpenStudio::Model::ThermalZone.new(model)
      thermal_zone.setName(name + " ThermalZone")
      new_space.setThermalZone(thermal_zone)
      
      result << new_space
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
    
    space.remove

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
    
    # point data available in the following formats
    # point_xy_2913 (NAD83(HARN) / Oregon North (ft)) (local projection)
    # point_xy_96703 (Equal Area Projection for the United States)
    # point_xy_4326 (WGS 84) (longitude, lattitude (deg))
    # point_xy_26910 (NAD 83 UTM Zone 10 )

    # instance variables
    @runner = runner
    @point_symbol = :point_xy_26910
    @min_x = Float::MAX 
    @min_y = Float::MAX 
    
    # read json
    buildings = {}
    File.open(city_json_path, 'r') do |file|
      buildings = JSON.parse(file.read, {:symbolize_names => true})
    end
    
    if buildings.length == 0
      runner.registerError("No buildings found in #{city_json_path}")
      return false
    end
    runner.registerInfo("#{buildings.length} buildings found")
    
    # find min and max x coordinate
    buildings.each_value do |building|
      building[:points].each do |point|
        val = point_to_xy(point)
        @min_x = val[0].to_f if val[0].to_f < @min_x
        @min_y = val[1].to_f if val[1].to_f < @min_y
      end
    end
    runner.registerInfo("min_x = #{@min_x}, min_y = #{@min_y}")
   
    # spaces of surrounding buildings
    intersecting_spaces = []
    
    # creating buildings
    if (building_id == "*All*")
    
      num_bldgs = 0
      max_bldgs = Float::INFINITY
      #max_bldgs = 10
      
      # make all buildings
      buildings.each_pair do |fid, building|
        if num_bldgs >= max_bldgs 
          next
        end
        #if !/Commercial/.match(building[:bldg_use])
        #  next
        #end
        
        spaces = create_building(fid, building, :space_per_building, model)
        if !spaces.nil? && !spaces.empty?
          num_bldgs += 1
        end
        
        GC.start
      end
      
      runner.registerInfo("Created #{num_bldgs} buildings")
      
    else
      
      # make requested building
      building = buildings[building_id.intern]
      
      if building.nil?
        runner.registerError("Cannot find building #{building_id}")
        return false
      end
      
      spaces = create_building(building_id, building, :space_per_floor, model)
      if spaces.nil? || spaces.empty?
        runner.registerError("Failed to create spaces for building #{building_id}")
        return false
      end
      
      # add surrounding buildings
      # todo: this should be surrounding_buildings instead
      intersecting_bldg_ids = building[:intersecting_bldg_fid].gsub('[','').gsub(']','')
      intersecting_bldg_ids.split(',').each do |intersecting_bldg_id|
        intersecting_building = buildings[intersecting_bldg_id.strip.intern]
              
        if intersecting_building.nil?
          runner.registerError("Cannot find intersecting building #{intersecting_bldg_id}")
          return false
        end
        
        spaces = create_building(intersecting_bldg_id, intersecting_building, :space_per_building, model)
        if spaces.nil? || spaces.empty?
          runner.registerError("Failed to create spaces for intersecting building #{intersecting_bldg_id}")
          return false
        end
        
        intersecting_spaces.concat(spaces)
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
    
    intersecting_spaces.each do |space|
      convert_to_shading_surface_group(space)
    end

    return true

  end
  
end

# register the measure to be used by the application
UrbanGeometryCreation.new.registerWithApplication
