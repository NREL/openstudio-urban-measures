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

class DatapointReports_Test < MiniTest::Unit::TestCase

  def is_openstudio_2?
    begin
      workflow = OpenStudio::WorkflowJSON.new
    rescue
      return false
    end
    return true
  end

  def model_in_path_default
    return "#{File.dirname(__FILE__)}/ExampleModel.osm"
  end

  def epw_path_default
    # make sure we have a weather data location
    epw = nil
    epw = OpenStudio::Path.new("#{File.dirname(__FILE__)}/USA_CO_Golden-NREL.724666_TMY3.epw")
    assert(File.exist?(epw.to_s))
    return epw.to_s
  end

  def run_dir(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    "#{File.dirname(__FILE__)}/output/#{test_name}"
  end

  def model_out_path(test_name)
    "#{run_dir(test_name)}/TestOutput.osm"
  end

  def workspace_path(test_name)
    if is_openstudio_2?
      return "#{run_dir(test_name)}/run/in.idf"
    else
      return "#{run_dir(test_name)}/ModelToIdf/in.idf"
    end
  end

  def sql_path(test_name)
    if is_openstudio_2?
      return "#{run_dir(test_name)}/run/eplusout.sql"
    else
      return "#{run_dir(test_name)}/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
    end
  end

  def report_path(test_name)
    "#{run_dir(test_name)}/report.html"
  end

  # method for running the test simulation using OpenStudio 1.x API
  def setup_test_1(test_name, epw_path)

    co = OpenStudio::Runmanager::ConfigOptions.new(true)
    co.findTools(false, true, false, true)

    if !File.exist?(sql_path(test_name))
      puts "Running EnergyPlus"

      wf = OpenStudio::Runmanager::Workflow.new("modeltoidf->energypluspreprocess->energyplus")
      wf.add(co.getTools())
      job = wf.create(OpenStudio::Path.new(run_dir(test_name)), OpenStudio::Path.new(model_out_path(test_name)), OpenStudio::Path.new(epw_path))

      rm = OpenStudio::Runmanager::RunManager.new
      rm.enqueue(job, true)
      rm.waitForFinished
    end
  end

  # method for running the test simulation using OpenStudio 2.x API
  def setup_test_2(test_name, epw_path)

    if !File.exist?(sql_path(test_name))
      osw_path = File.join(run_dir(test_name), 'in.osw')
      osw_path = File.absolute_path(osw_path)

      workflow = OpenStudio::WorkflowJSON.new
      workflow.setSeedFile(File.absolute_path(model_out_path(test_name)))
      workflow.setWeatherFile(File.absolute_path(epw_path))
      workflow.saveAs(osw_path)

      cli_path = OpenStudio.getOpenStudioCLI
      cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
      puts cmd
      system(cmd)
    end
  end

  # create test files if they do not exist when the test first runs
  def setup_test(test_name, idf_output_requests, model_in_path = model_in_path_default, epw_path = epw_path_default)

    if !File.exist?(run_dir(test_name))
      FileUtils.mkdir_p(run_dir(test_name))
    end
    assert(File.exist?(run_dir(test_name)))

    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end

    assert(File.exist?(model_in_path))

    if File.exist?(model_out_path(test_name))
      FileUtils.rm(model_out_path(test_name))
    end

    # convert output requests to OSM for testing, OS App and PAT will add these to the E+ Idf
    workspace = OpenStudio::Workspace.new("Draft".to_StrictnessLevel, "EnergyPlus".to_IddFileType)
    workspace.addObjects(idf_output_requests)
    rt = OpenStudio::EnergyPlus::ReverseTranslator.new
    request_model = rt.translateWorkspace(workspace)

    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(model_in_path)
    assert((not model.empty?))
    model = model.get
    model.addObjects(request_model.objects)
    model.save(model_out_path(test_name), true)

    if is_openstudio_2?
      setup_test_2(test_name, epw_path)
    else
      setup_test_1(test_name, epw_path)
    end
  end

  def test_good_argument_values
    test_name = 'good_argument_values'
    model_in_path = "#{File.dirname(__FILE__)}/example_model.osm"

    # create an instance of the measure
    measure = DatapointReports.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # get arguments
    arguments = measure.arguments
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash["city_db_url"] = "http://localhost:3000"
    args_hash["user_name"] = "test@nrel.gov"
    args_hash["password"] = "testing123"
    args_hash["project_id"] = "0"
    args_hash["datapoint_id"] = "0"

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # get the energyplus output requests, this will be done automatically by OS App and PAT
    idf_output_requests = measure.energyPlusOutputRequests(runner, argument_map)
    #assert_equal(3, idf_output_requests.size)

    # mimic the process of running this measure in OS App or PAT
    # todo - create alternate setup or new args to pass in IDF with tariff objects using all fuels
    epw_path = epw_path_default
    setup_test(test_name,idf_output_requests,model_in_path)

    assert(File.exist?(model_out_path(test_name)))
    assert(File.exist?(sql_path(test_name)))
    assert(File.exist?(epw_path))

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_out_path(test_name)))
    runner.setLastEnergyPlusWorkspacePath(OpenStudio::Path.new(workspace_path(test_name)))
    runner.setLastEpwFilePath(epw_path)
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path(test_name)))

    # delete the output if it exists
    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end
    assert(!File.exist?(report_path(test_name)))

    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(run_dir(test_name))

      # run the measure
      measure.run(runner, argument_map)
      result = runner.result
      show_output(result)
      assert_equal('Success', result.value.valueName)

    ensure
      Dir.chdir(start_dir)
    end

    # make sure the report file exists
    assert(File.exist?("#{run_dir(test_name)}/report.csv"))
    assert(File.exist?("#{run_dir(test_name)}/report.json"))
  end

end
