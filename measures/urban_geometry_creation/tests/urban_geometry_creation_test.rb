######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

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
    
    project_id = "5890e14c6eeb881368000002"
    #feature_id = "5890e1566eeb881368000003"
    feature_id = "5890e1566eeb881368000021"
    
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
    args_hash["project_id"] = project_id
    args_hash["feature_id"] = feature_id
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
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/#{feature_id}.osm")
    model.save(output_file_path,true)
    
    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
  end

end
