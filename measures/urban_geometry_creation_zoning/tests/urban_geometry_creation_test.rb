require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class UrbanGeometryCreationTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end
  
  def test_is_shadowed
  
    meas = UrbanGeometryCreation.new
    meas.origin_lat_lon = OpenStudio::PointLatLon.new(40, -120, 0)

    # y is north, x is east, z is up
    
    # points on ground
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(10, 0, 0))) # West
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(Math.sqrt(50), -Math.sqrt(50), 0)))  # South West
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(0, -10, 0))) # South
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(-Math.sqrt(50), -Math.sqrt(50), 0))) # South East
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(-10, 0, 0))) # East
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(-Math.sqrt(50), Math.sqrt(50), 0))) # North East
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(0, 10, 0))) # North
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(Math.sqrt(50), Math.sqrt(50), 0))) # North West
    
    # points 10 m up
    assert(meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(10, 0, 10))) # West
    assert(meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(Math.sqrt(50), -Math.sqrt(50), 10)))  # South West
    assert(meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(0, -10, 10))) # South
    assert(meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(-Math.sqrt(50), -Math.sqrt(50), 10))) # South East
    assert(meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(-10, 0, 10))) # East
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(-Math.sqrt(50), Math.sqrt(50), 10))) # North East
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(0, 10, 10))) # North
    assert(!meas.point_is_shadowed(OpenStudio::Point3d.new(0, 0, 0), OpenStudio::Point3d.new(Math.sqrt(50), Math.sqrt(50), 10))) # North West

  end

  def test_one_building
    # create an instance of the measure
    measure = UrbanGeometryCreation.new
    
    # create an empty model
    model = OpenStudio::Model::Model.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    city_db_url = "http://localhost:3000"
    #city_db_url = "http://insight4.hpc.nrel.gov:8081/"
    
    project_name = "Denver 1"
    source_id = "176439"
    source_name = "NREL_GDS"
    
    surrounding_buildings = "None"
    #surrounding_buildings = "ShadingOnly"
    #surrounding_buildings = "All"
   
    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["city_db_url"] = city_db_url
    args_hash["project_name"] = project_name
    args_hash["source_id"] = source_id
    args_hash["source_name"] = source_name
    args_hash["surrounding_buildings"] = surrounding_buildings

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/#{source_id}.osm")
    model.save(output_file_path,true)
    
    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
  end

end
