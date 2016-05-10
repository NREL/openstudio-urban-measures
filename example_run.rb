# this example runs without using the web interface to query input data

require 'json'
require 'net/http'
require 'fileutils'

include = ""
#openstudio_2_0 = "E:/openstudio-2-0/build"
#include = "-I '#{File.join(openstudio_2_0, 'OSCore-prefix/src/OSCore-build/ruby/Debug/')}"

space_types = ["Office", "Single-Family"]
  

def merge(workflow, properties)
  workflow[:steps].each do |step|
    step[:arguments].each do |argument|
      name = argument[:name]
      if properties[name.to_sym]
        value = properties[name.to_sym]
        puts "Setting '#{name}' of '#{step[:measure_dir_name]}' to '#{value}'"
        argument[:value] = value
      end
    end
  end
  return workflow
end

# configure a workflow with building data
def configure(workflow, datapoint, building, region)

  # configure with region first
  workflow = merge(workflow, region[:properties])

  # configure with building next
  workflow = merge(workflow, building[:properties])
  
  # configure with datapoint last
  workflow = merge(workflow, datapoint)
  
  # weather_file comes from the region properties
  workflow[:weather_file] = region[:properties][:weather_file_name]
  
  return workflow
end

space_types.each do |space_type|
    
  # these are made up for now
  datapoint_json = {:properties=>{}}
  building_json = {:properties=>{:space_type => space_type}}
  region_json = {:properties=>{:weather_file_name => "USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw"}}


  # load the workflows
  baseline_osw = nil
  File.open(File.join(File.dirname(__FILE__), "/workflows/testing_baseline.osw"), 'r') do |f|
    baseline_osw = JSON::parse(f.read, :symbolize_names => true)
  end

  retrofit_osw = nil
  File.open(File.join(File.dirname(__FILE__), "/workflows/testing_retrofit.osw"), 'r') do |f|
    retrofit_osw = JSON::parse(f.read, :symbolize_names => true)
  end

  # configure the osws with jsons
  baseline_osw = configure(baseline_osw, datapoint_json, building_json, region_json)
  retrofit_osw = configure(retrofit_osw, datapoint_json, building_json, region_json)

  # set up the directories
  baseline_osw_dir = File.join(File.dirname(__FILE__), "/run/testing_#{space_type}/baseline/")
  FileUtils.rm_rf(baseline_osw_dir)
  FileUtils.mkdir_p(baseline_osw_dir)

  retrofit_osw_dir = File.join(File.dirname(__FILE__), "/run/testing_#{space_type}/retrofit/")
  FileUtils.rm_rf(retrofit_osw_dir)
  FileUtils.mkdir_p(retrofit_osw_dir)

  # save the configured osws
  baseline_osw_path = "#{baseline_osw_dir}/in.osw"
  File.open(baseline_osw_path, 'w') do |f|
    f << JSON.generate(baseline_osw)
  end
    
  retrofit_osw_path = "#{retrofit_osw_dir}/in.osw"
  File.open(retrofit_osw_path, 'w') do |f|
    f << JSON.generate(retrofit_osw)
  end
    
  # run them
  run_script = File.join(File.dirname(__FILE__), "run.rb")

  command = "bundle exec #{RbConfig.ruby} #{include} #{run_script} #{baseline_osw_path}"
  puts command
  system(command)

  #command = "bundle exec #{RbConfig.ruby} #{include} #{run_script} #{retrofit_osw_path}"
  #puts command
  #system(command)
end