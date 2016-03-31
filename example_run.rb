require 'json'
require 'net/http'

openstudio_2_0 = "E:/openstudio-2-0/build"
city_db_url = "http://insight4.hpc.nrel.gov:8081/"
source_id = "445"
source_name = "NREL_GDS"

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
  
  # run dir is datapoint id
  workflow[:run_directory] = "./#{datapoint[:id]}"
  
  return workflow
end
 	
# load the workflow
baseline_osw = nil
File.open(File.join(File.dirname(__FILE__), "/workflows/baseline.osw"), 'r') do |f|
  baseline_osw = JSON::parse(f.read, :symbolize_names => true)
end
  
# get the building
port = 80
if md = /http:\/\/(.*):(\d+)/.match(city_db_url)
  city_db_url = md[1]
  port = md[2]
elsif /http:\/\/([^:\/]*)/.match(city_db_url)
  city_db_url = md[1]
end
    
params = {}
params[:commit] = 'Search'
params[:source_id] = source_id
params[:source_name] = source_name
params[:feature_types] = ['Building']
    
http = Net::HTTP.new(city_db_url, port)
request = Net::HTTP::Post.new("/api/search.json")
request.add_field('Content-Type', 'application/json')
request.add_field('Accept', 'application/json')
request.body = JSON.generate(params)
# DLM: todo, get these from environment variables or as measure inputs?
request.basic_auth("testing@nrel.gov", "testing123")
  
response = http.request(request)
if  response.code != '200' # success
  fail("Bad response #{response.code}")
end

feature_collection = JSON.parse(response.body, :symbolize_names => true)
if feature_collection[:features].nil?
  fail("No features found in #{feature_collection}")
elsif feature_collection[:features].empty?
  fail("No features found in #{feature_collection}")
elsif feature_collection[:features].size > 1
  fail("Multiple features found in #{feature_collection}")
end
    
building_json = feature_collection[:features][0]
id = building_json[:properties][:id]

# these are made up for now
datapoint_json = {:id=>id}
region_json = {:properties=>{:weather_file_name=>"USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw"}}

# configure the osw with building_json
baseline_osw = configure(baseline_osw, datapoint_json, building_json, region_json)

# save the configured osw
baseline_osw_path = File.join(File.dirname(__FILE__), "/run/#{id}_baseline.osw")
File.open(baseline_osw_path, 'w') do |f|
  f << JSON.generate(baseline_osw)
end
  
# run it 
ruby = File.join(openstudio_2_0, "Ruby-prefix/src/Ruby/bin/ruby")
include = File.join(openstudio_2_0, "OSCore-prefix/src/OSCore-build/ruby/Debug/")
cli = File.join(openstudio_2_0, "OSCore-prefix/src/OSCore-build/ruby/Debug/openstudio_cli.rb")

command = "#{ruby} -I #{include} #{cli} #{baseline_osw_path}"
puts command
#system(command)