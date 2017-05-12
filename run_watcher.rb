require 'rest-client'
require 'json'

require_relative 'runner'
require_relative 'config'

url = UrbanOptConfig::URL
openstudio_exe = UrbanOptConfig::OPENSTUDIO_EXE
openstudio_measures = UrbanOptConfig::OPENSTUDIO_MEASURES
openstudio_files = UrbanOptConfig::OPENSTUDIO_FILES
user_name = UrbanOptConfig::USER_NAME
user_pwd = UrbanOptConfig::USER_PWD
max_datapoints = UrbanOptConfig::MAX_DATAPOINTS
num_parallel = UrbanOptConfig::NUM_PARALLEL

def get_all_project_ids(url, user_name, user_pwd)
  result = []
  
  request = RestClient::Resource.new("#{url}/api/projects.json", user: user_name, password: user_pwd)
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
  runner = Runner.new(url, openstudio_exe, openstudio_measures, openstudio_files, project_id, user_name, user_pwd, max_datapoints, num_parallel)
  runner.update_measures
  runner.clear_results
end

# main loop
while true

  project_ids = get_all_project_ids(url, user_name, user_pwd)
  project_ids.each do |project_id|

    runner = Runner.new(url, openstudio_exe, openstudio_measures, openstudio_files, project_id, user_name, user_pwd, max_datapoints, num_parallel)
    dirs = runner.create_osws
    puts "running dirs #{dirs}"
    runner.run_osws(dirs)
    if dirs.size > 0
      runner.save_results
    end
  end
  
  STDOUT.flush
  sleep 1

end