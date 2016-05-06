require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AddDistrictSystemTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end
  
  def do_test(seed_path, system_type)

    # create an instance of the measure
    measure = AddDistrictSystem.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    
    model = translator.loadModel(seed_path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["system_type"] = system_type
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
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/#{seed_path.stem}_#{system_type.gsub(' ','_')}.osm")
    model.save(output_file_path,true)
    
    return result
  end
  
  def test_none()
    seed_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/example_model.osm")
    result = do_test(seed_path, "None")
    
    # assert that it ran correctly
    assert_equal("NA", result.value.valueName)
  end
  
  def test_chilled_hot_water()
    seed_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/example_model.osm")
    result = do_test(seed_path, "Central Hot and Chilled Water")
    
    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
  end
  
end