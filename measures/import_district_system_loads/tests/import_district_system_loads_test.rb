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

class ImportDistrictSystemLoadsTest < MiniTest::Unit::TestCase
  # def setup
  # end

  # def teardown
  # end

  def test_good_argument_values
    # create an instance of the measure
    measure = ImportDistrictSystemLoads.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # get arguments
    model = OpenStudio::Model::Model.new
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash['city_db_url'] = 'http://localhost:3000'
    args_hash['project_id'] = '57965ea0c44c8d3924000002'
    args_hash['building_workflow_id'] = '57965ec1c44c8d3924000019'
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
    if File.exist?(File.dirname(__FILE__) + '/output')
      FileUtils.rm_rf(File.dirname(__FILE__) + '/output')
    end
    FileUtils.mkdir_p(File.dirname(__FILE__) + '/output')
    Dir.chdir(File.dirname(__FILE__) + '/output')

    begin
      measure.run(model, runner, argument_map)
    ensure
      Dir.chdir(pwd)
    end

    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + '/output/test_output.osm')
    model.save(output_file_path, true)
  end
end
