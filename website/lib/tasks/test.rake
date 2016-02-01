require 'rest-client'

namespace :testing do

  # Test batch_upload
  desc 'Batch upload features  (api/batch_upload)'
  task batch_upload_features: :environment do
   
    #filename = "#{Rails.root}/data/san_francisco_bldg_footprints_4326.geojson"
    filename = "#{Rails.root}/lib/test.geojson"

    json_file = MultiJson.load(File.read(filename))
    json_request = JSON.generate('data' => json_file)

    #puts "POST http://localhost:3000/api/structures/batch_upload, parameters: #{json_request}"
    begin
      request = RestClient::Resource.new('http://localhost:3000/api/batch_upload')
      response = request.post(json_request, content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}" if response.code == 201
    rescue => e
      puts "ERROR: #{e.response}"
    end
  end

  # Test export
  desc 'Export features (api/export)'
  task export_features: :environment do

    # set array of types to return. Choices:  All, Building, Region, Taxlot, District System
    types = ['all']
    json_request = JSON.generate('types' => types)
    
    begin
      request = RestClient::Resource.new('http://localhost:3000/api/export')
      response = request.post(json_request, content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}" 
    rescue => e
      puts "ERROR: #{e.response}"
    end




  end

end
