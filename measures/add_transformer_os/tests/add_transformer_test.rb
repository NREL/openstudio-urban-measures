require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

class AddTransformer_Test < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_good_argument_values

    # create an instance of the measure
    measure = AddTransformer.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load test workspace
    test_idf = File.join(File.dirname(__FILE__), "transformer_loads.idf") 
    workspace = OpenStudio::Workspace.load(OpenStudio::Path.new(test_idf)).get

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal("Success", result.value.valueName)

    # check that there is now 1 transformer object
    assert_equal(1, workspace.getObjectsByType("ElectricLoadCenter:Transformer".to_IddObjectType).size)

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.idf")
    workspace.save(output_file_path,true)
  end

end
