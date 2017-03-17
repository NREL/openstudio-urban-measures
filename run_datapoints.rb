require_relative 'runner'
require_relative 'config'

url = UrbanOptConfig::URL
openstudio_exe = UrbanOptConfig::OPENSTUDIO_EXE
openstudio_measures = UrbanOptConfig::OPENSTUDIO_MEASURES
user_name = UrbanOptConfig::USER_NAME
user_pwd = UrbanOptConfig::USER_PWD
max_datapoints = UrbanOptConfig::MAX_DATAPOINTS
num_parallel = UrbanOptConfig::NUM_PARALLEL
project_id = UrbanOptConfig::PROJECT_ID
datapoint_ids = UrbanOptConfig::DATAPOINT_IDS

runner = Runner.new(url, openstudio_exe,openstudio_measures, project_id, user_name, user_pwd, max_datapoints, num_parallel)
runner.update_measures
runner.clear_results(datapoint_ids)

dirs = []
datapoint_ids.each do |datapoint_id|
  dirs << runner.create_osw(datapoint_id)
end

runner.run_osws(dirs)
#runner.save_results
