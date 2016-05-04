require 'rest-client'
require 'base64'

#url = 'http://localhost:3000'
url = 'http://insight4.hpc.nrel.gov:8081'
project_id = '5728c605b03b420068000450'
user_name = 'test@nrel.gov'
user_pwd = 'testing123'
datapoint_id = '5728c77eb03b420068000454'

# send status
datapoint = {}
datapoint[:id] = datapoint_id
datapoint[:status] = "Hello"

params = {}
params[:project_id] = project_id
params[:datapoint] = datapoint

request = RestClient::Resource.new("#{url}/api/datapoint", user: user_name, password: user_pwd)
response = request.post(params, content_type: :json, accept: :json)


# send this file
the_file = ''
File.open(__FILE__, 'rb') do |file|
  the_file = Base64.strict_encode64(file.read)
end

file_data = {}
file_data[:file_name] = File.basename(__FILE__)
file_data[:file] = the_file

params = {}
params[:datapoint_id] = datapoint_id
params[:file_data] = file_data

request = RestClient::Resource.new("#{url}/api/datapoint_file", user: user_name, password: user_pwd)
response = request.post(params, content_type: :json, accept: :json)
