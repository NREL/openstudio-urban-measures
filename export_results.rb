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
project_id = UrbanOptConfig::PROJECT_ID
datapoint_ids = UrbanOptConfig::DATAPOINT_IDS

runner = Runner.new(url, openstudio_exe, openstudio_measures, openstudio_files, project_id, user_name, user_pwd, max_datapoints, num_parallel)
runner.save_results