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

  def test_one_building
    # create an instance of the measure
    measure = UrbanGeometryCreation.new
    
    # create an empty model
    model = OpenStudio::Model::Model.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    city_db_url = "http://localhost:3000"
    building_id = "56ddda0fc44c8d327000069e"
    
    # "source_id": "74"
    # 8th building in list
    # 649 Bay St, San Francisco, CA
    # http://localhost:3000/buildings/56ddda0fc44c8d327000069e

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["city_db_url"] = city_db_url
    args_hash["id"] = building_id

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
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/#{building_id}.osm")
    model.save(output_file_path,true)
    
    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
  end

end
