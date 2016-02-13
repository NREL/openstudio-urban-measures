require 'json'
require 'rest-client'

user_name = 'test@nrel.gov'
user_pwd = 'testing123'

filenames = []
filenames << "#{File.dirname(__FILE__)}/grid_data_OR.geojson"
filenames << "#{File.dirname(__FILE__)}/grid_data_CO.geojson"
filenames << "#{File.dirname(__FILE__)}/denver_land_use_08031004103.clean.geojson"
filenames << "#{File.dirname(__FILE__)}/denver_bldg_footprints_08031004103.clean.geojson"

filenames.each do |filename|
  json_file = JSON.load(File.read(filename))
  json_request = JSON.generate('data' => json_file)

  #puts "POST http://localhost:3000/api/structures/batch_upload, parameters: #{json_request}"
  begin
    request = RestClient::Resource.new('http://localhost:3000/api/batch_upload', user: user_name, password: user_pwd)
    response = request.post(json_request, content_type: :json, accept: :json)
    puts "Status: #{response.code}"
    puts "SUCCESS: #{response.body}" if response.code == 201
  rescue => e
    puts "ERROR: #{e.response}"
  end
end