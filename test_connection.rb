
require_relative 'config'
require 'rest-client'
require 'json'

logger = UrbanOptConfig::LOGGER
url = UrbanOptConfig::URL
openstudio_exe = UrbanOptConfig::OPENSTUDIO_EXE
openstudio_measures = UrbanOptConfig::OPENSTUDIO_MEASURES
openstudio_files = UrbanOptConfig::OPENSTUDIO_FILES
user_name = UrbanOptConfig::USER_NAME
user_pwd = UrbanOptConfig::USER_PWD
max_datapoints = UrbanOptConfig::MAX_DATAPOINTS
num_parallel = UrbanOptConfig::NUM_PARALLEL
clear_results = UrbanOptConfig::CLEAR_RESULTS
project_id = UrbanOptConfig::PROJECT_ID
datapoint_ids = UrbanOptConfig::DATAPOINT_IDS


# Can you get the project?
logger.info("get_project")
result = nil
begin
  request = RestClient::Resource.new("#{url}", user: user_name, password: user_pwd)
  response = request["/api/project?project_id=#{project_id.to_s}"].get(content_type: :json, accept: :json)
  project = JSON.parse(response.body, :symbolize_names => true)
  result = project[:project]
  logger.info("Get Project: SUCCESS!")
 rescue => e
  logger.error("Error in get_project: #{e.response}")
end   

# Can you get all of the datapoint ids?
logger.info("get_datapoint_ids_by_type")
begin
	request = RestClient::Resource.new("#{url}", user: user_name, password: user_pwd)
	response = request["/api/datapoints?project_id=#{project_id.to_s}"].get(content_type: :json, accept: :json)

	datapoints = JSON.parse(response.body, :symbolize_names => true)
	logger.debug("#{datapoints.size} total datapoints retrieved")

  if datapoint_ids.length > 0
    # select datapoints down to subset specified in config file
    datapoints = datapoints.select{ |dp| datapoint_ids.include? dp[:id] }
  end
  logger.debug("#{datapoints.size} datapoints selected after comparing to config file datapoints")

  # separate buildings, district systems, and transformers
  new_dps = {}
  new_dps[:buildings] = datapoints.select { |dp| dp[:feature_type] == 'Building'}
  new_dps[:district_systems] = datapoints.select { |dp| dp[:feature_type] == 'District System' && dp[:district_system_type] && dp[:district_system_type] != 'Transformer'}     
  new_dps[:transformers] = datapoints.select { |dp| dp[:feature_type] == 'District System' && dp[:district_system_type] && dp[:district_system_type] == 'Transformer'}

  result = {}
  new_dps.each do |key, dpArr|
    result[key] = dpArr.map{|x| x[:id]}
  end
  logger.debug("RESULTS: #{result}")

rescue => e
  logger.error("Error in get_datapoint_ids_by_type: #{e.response}")
end   




