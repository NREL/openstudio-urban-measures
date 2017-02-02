require 'rest-client'
require 'json'

require_relative 'runner'

url = 'http://localhost:3000'
#url = 'http://insight4.hpc.nrel.gov:8081'

#openstudio_exe = 'E:/openstudio/build/Products/Debug/openstudio.exe'
openstudio_exe = 'C:/Program Files/OpenStudio 2.0.1/bin/openstudio.exe'

user_name = 'test@nrel.gov'
user_pwd = 'testing123'
max_datapoints = Float::INFINITY
#max_datapoints = 7
num_parallel = 7

def get_all_project_ids(url, user_name, user_pwd)
  result = []
  
  request = RestClient::Resource.new("#{url}/projects.json", user: user_name, password: user_pwd)
  response = request.get(content_type: :json, accept: :json)

  projects = JSON.parse(response.body, :symbolize_names => true)
  projects.each do |project|
    result << project[:id]
  end

  puts "get_all_project_ids = #{result.join(',')}"
  return result
end

project_ids = get_all_project_ids(url, user_name, user_pwd)
project_ids.each do |project_id|
  runner = Runner.new(url, openstudio_exe, project_id, user_name, user_pwd, max_datapoints, num_parallel)
  runner.update_measures
  #runner.clear_results
end

# main loop
while true

  project_ids = get_all_project_ids(url, user_name, user_pwd)
  project_ids.each do |project_id|

    runner = Runner.new(url, openstudio_exe, project_id, user_name, user_pwd, max_datapoints, num_parallel)
    dirs = runner.create_osws
    puts "running dirs #{dirs}"
    runner.run_osws(dirs)
    runner.save_results
  end
  
  STDOUT.flush
  sleep 1

end