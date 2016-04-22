# this example runs without using the web interface to query input data

require 'json'
require 'net/http'
require 'fileutils'

openstudio_2_0 = "E:/openstudio-2-0/build"

city_db_url = "http://localhost:3000"
#city_db_url = "http://insight4.hpc.nrel.gov:8081/"
project_name = "san_francisco"
source_id = "98628"
source_name = "NREL_GDS"

datapoint_id = "#{project_name}_#{source_id}"

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
 	
# load the workflow
baseline_osw = nil
File.open(File.join(File.dirname(__FILE__), "/workflows/baseline.osw"), 'r') do |f|
  baseline_osw = JSON::parse(f.read, :symbolize_names => true)
end
  
# these are made up for now
datapoint_json = {:id=>datapoint_id}
building_json = {:properties=>{:city_db_url => city_db_url, :project_name => project_name, :source_id => source_id, :source_name => source_name}}
region_json = {:properties=>{:weather_file_name=>"USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw"}}

# configure the osw with building_json
baseline_osw = configure(baseline_osw, datapoint_json, building_json, region_json)

# set up the directory
baseline_osw_dir = File.join(File.dirname(__FILE__), "/run/#{datapoint_id}_baseline/")
FileUtils.rm_rf(baseline_osw_dir)
FileUtils.mkdir_p(baseline_osw_dir)

# save the configured osw
baseline_osw_path = "#{baseline_osw_dir}/in.osw"
File.open(baseline_osw_path, 'w') do |f|
  f << JSON.generate(baseline_osw)
end
  
# run it 
include = File.join(openstudio_2_0, "OSCore-prefix/src/OSCore-build/ruby/Debug/")
run_script = File.join(File.dirname(__FILE__), "run.rb")

command = "#{RbConfig.ruby} -I #{include} #{run_script} #{baseline_osw_path}"
puts command
system(command)
