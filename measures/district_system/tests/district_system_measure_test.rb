require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class DistrictSystemTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_good_argument_values
    # create an instance of the measure
    measure = DistrictSystem.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # get arguments
    model = OpenStudio::Model::Model.new
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["city_db_url"] = "http://localhost:3000"
    args_hash["project_id"] = "57965ea0c44c8d3924000002"
    args_hash["building_workflow_id"] = "57965ec1c44c8d3924000019"
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    pwd = Dir.pwd
    if File.exists?(File.dirname(__FILE__) + "/output")
      FileUtils.rm_rf(File.dirname(__FILE__) + "/output")
    end
    FileUtils.mkdir_p(File.dirname(__FILE__) + "/output")
    Dir.chdir(File.dirname(__FILE__) + "/output")
    
    begin
      measure.run(model, runner, argument_map)
    ensure
      Dir.chdir(pwd)
    end
    
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.osm")
    model.save(output_file_path,true)
  end

end
