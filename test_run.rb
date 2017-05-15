######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

require 'json'
require 'parallel'
require 'fileutils'
require 'csv'
require_relative 'config'
require_relative 'map_properties'

openstudio_exe = UrbanOptConfig::OPENSTUDIO_EXE

run_retrofit = true
num_parallel = 7
jobs = []

buildings_to_run = []
#buildings_to_run = ['Vacant', 'Small-Office-All-Electric']

# project_json = {:properties=>{:weather_file_name => "USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw", :climate_zone => "3C"}}
project_json = {:properties=>{:weather_file_name => "USA_CO_Denver.Intl.AP.725650_TMY3.epw", :climate_zone => "5B"}}

def convert_value(value)
  if value.nil?
    return nil
  elsif value.to_i.to_s == value.to_s 
    return value.to_i
  elsif value.to_f.to_s == value.to_s 
    return value.to_f
  end
  return value
end

buildings = []
option_sets = []
headers_1 = []
headers_2 = []
CSV.foreach('test_buildings.csv') do |row|
  if headers_1.empty?
    row.each {|header| headers_1 << header.to_s}
  elsif headers_2.empty?
    row.each {|header| headers_2 << header.to_sym}    
  else
    building = {}
    option_set = []
    headers_1.each_index do |i|
      if headers_1[i] == "Feature"
        if row[i]
          building[headers_2[i]] = convert_value(row[i])
        end
      else
        if row[i]
          option_set << {:measure_step_name => headers_1[i], :argument => headers_2[i].to_sym, :value => row[i]}
        end
      end
    end
    buildings << building
    option_sets << option_set
  end
end

buildings.each_index do |i|
  
  building = buildings[i]
  option_set = option_sets[i]

  # use include_in_energy_analysis to skip this run
  if building[:include_in_energy_analysis] == 0 || building[:include_in_energy_analysis] == "false"
    puts "Skipping '#{building[:name]}'"
    next
  end
  
  # only run certain buildings
  if buildings_to_run && buildings_to_run.size > 0 && buildings_to_run.index(building[:name]).nil?
    puts "Skipping '#{building[:name]}'"
    next
  end

  # configure jsons
  building_json = {:properties=>building}

  name = building[:name]

  # load the workflows
  baseline_osw = nil
  File.open(File.join(File.dirname(__FILE__), "/workflows/testing_baseline.osw"), 'r') do |f|
    baseline_osw = JSON::parse(f.read, :symbolize_names => true)
  end
  
  if run_retrofit
    # easier than deep cloning baseline_osw
    retrofit_osw = nil
    File.open(File.join(File.dirname(__FILE__), "/workflows/testing_baseline.osw"), 'r') do |f|
      retrofit_osw = JSON::parse(f.read, :symbolize_names => true) # easier than deep cloning
    end
  end
  
  # configure the osws with jsons
  baseline_osw = configure_workflow(baseline_osw, building_json, project_json, false)
  baseline_osw[:file_paths] = UrbanOptConfig::OPENSTUDIO_FILES
  baseline_osw[:measure_paths] = UrbanOptConfig::OPENSTUDIO_MEASURES
  baseline_osw = merge_workflow(baseline_osw, option_set)
  if run_retrofit
    retrofit_osw = configure_workflow(retrofit_osw, building_json, project_json, true)
    retrofit_osw[:file_paths] = UrbanOptConfig::OPENSTUDIO_FILES
    retrofit_osw[:measure_paths] = UrbanOptConfig::OPENSTUDIO_MEASURES    
    retrofit_osw = merge_workflow(retrofit_osw, option_set)
  end

  # set up the directories
  baseline_osw_dir = File.join(File.dirname(__FILE__), "/run/testing/#{name}_baseline/")
  FileUtils.rm_rf(baseline_osw_dir)
  FileUtils.mkdir_p(baseline_osw_dir)

  retrofit_osw_dir = File.join(File.dirname(__FILE__), "/run/testing/#{name}_retrofit/")
  FileUtils.rm_rf(retrofit_osw_dir)
  FileUtils.mkdir_p(retrofit_osw_dir) if run_retrofit
  
  # save the configured osws
  baseline_osw_path = "#{baseline_osw_dir}/in.osw"
  File.open(baseline_osw_path, 'w') do |f|
    f << JSON.pretty_generate(baseline_osw)
  end
    
  if run_retrofit
    retrofit_osw_path = "#{retrofit_osw_dir}/in.osw"
    File.open(retrofit_osw_path, 'w') do |f|
      f << JSON.pretty_generate(retrofit_osw)
    end
  end
    
  # run them
  run_script = File.join(File.dirname(__FILE__), "run.rb")

  jobs << "'#{openstudio_exe}' run -w '#{baseline_osw_path}'"

  if run_retrofit
    jobs << "'#{openstudio_exe}' run -w '#{retrofit_osw_path}'"
  end
end

# run the jobs
Parallel.each(jobs, in_threads: num_parallel) do |job|
  puts job
  system(job)
end