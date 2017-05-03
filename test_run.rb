# this example runs without using the web interface to query input data

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
headers = []
CSV.foreach('test_buildings.csv') do |row|
  if headers.empty?
    row.each {|header| headers << header.to_sym}
  else
    building = {}
    headers.each_index do |i|
      if row[i]
        building[headers[i]] = convert_value(row[i])
      end
    end
    buildings << building
  end
end

buildings.each do |building|
  building[:heating_source] = "Gas" if building[:heating_source].nil?
  building[:cooling_source] = "Electric" if building[:cooling_source].nil? 
  building[:system_type] = "Forced air" if building[:system_type].nil? 
end

buildings.each do |building|

  # use include_in_energy_analysis to skip this run
  if building[:include_in_energy_analysis] == 0 || building[:include_in_energy_analysis] == "false"
    next
  end

  # configure jsons
  datapoint_json = {:properties=>{}}
  building_json = {:properties=>building}
  # region_json = {:properties=>{:weather_file_name => "USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw", :climate_zone => "3C"}}
  region_json = {:properties=>{:weather_file_name => "USA_CO_Denver.Intl.AP.725650_TMY3.epw", :climate_zone => "5B"}}

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
  baseline_osw = configure_workflow(baseline_osw, datapoint_json, building_json, region_json, false)
  if run_retrofit
    retrofit_osw = configure_workflow(retrofit_osw, datapoint_json, building_json, region_json, true)
  end

  # set up the directories
  baseline_osw_dir = File.join(File.dirname(__FILE__), "/run/testing_#{name}/baseline/")
  FileUtils.rm_rf(baseline_osw_dir)
  FileUtils.mkdir_p(baseline_osw_dir)

  retrofit_osw_dir = File.join(File.dirname(__FILE__), "/run/testing_#{name}/retrofit/")
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