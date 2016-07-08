require 'rest-client'
require 'parallel'
require 'json'

require_relative 'runner'

url = 'http://localhost:3000'
#url = 'http://insight4.hpc.nrel.gov:8081'
user_name = 'test@nrel.gov'
user_pwd = 'testing123'
#max_datapoints = Float::INFINITY
max_datapoints = 2
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

# main loop
while true

  project_ids = get_all_project_ids(url, user_name, user_pwd)
  project_ids.each do |project_id|

    runner = Runner.new(url, project_id, user_name, user_pwd, max_datapoints, num_parallel)
    dirs = runner.create_osws
    runner.run_osws(dirs)
    runner.save_results
  end
  
  sleep 1
  
end