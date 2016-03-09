require 'rest-client'

namespace :testing do
  # Test batch_upload
  desc 'Batch upload features  (api/batch_upload)'
  task batch_upload_features: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'

    # filename = "#{Rails.root}/data/san_francisco_bldg_footprints_4326.geojson"
    filename = "#{Rails.root}/data/US_CA_Tract_06075010300.clean.geojson"
    #filename = "#{Rails.root}/lib/test.geojson"

    json_file = MultiJson.load(File.read(filename))
    json_request = JSON.generate('data' => json_file)

    # puts "POST http://localhost:3000/api/structures/batch_upload, parameters: #{json_request}"
    begin
      request = RestClient::Resource.new('http://localhost:3000/api/batch_upload', user: @user_name, password: @user_pwd)
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
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'

    # set array of types to return. Choices:  All, Building, Region, Taxlot, District System
    types = ['all']
    json_request = JSON.generate('types' => types)

    begin
      request = RestClient::Resource.new('http://localhost:3000/api/export', user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end
  end

  # Test import workflow
  desc 'POST workflow'
  task post_workflow: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'

    filename = "#{Rails.root}/data/test.osw"
    json_file = MultiJson.load(File.read(filename))
    json_request = JSON.generate('workflow' => json_file)

    begin
      request = RestClient::Resource.new('http://localhost:3000/api/workflow', user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end
  end

  # Test import workflow_file
  desc 'POST workflow_file'
  task post_workflow_file: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'

    # only works after saving a structure, so get a valid one
    workflow = Workflow.where(osd_id: 'e7c2d3e7-7d9b-4a90-837c-44b44f77a89b').first
    workflow_id = workflow.id.to_s

    file = File.open("#{Rails.root}/data/workflow_test_zipfile.zip", 'rb')
    the_file = Base64.strict_encode64(file.read)
    file.close
    # file_data param
    file_data = {}
    file_data['file_name'] = 'test_zip.zip'
    file_data['file'] = the_file

    json_request = JSON.generate('workflow_id' => workflow_id, 'file_data' => file_data)
    # puts "POST http://<user>:<pwd>@<base_url>/api/v1/related_file, parameters: #{json_request}"

    begin
      request = RestClient::Resource.new('http://localhost:3000/api/workflow_file', user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      if response.code == 201
        puts "SUCCESS: #{response.body}"
      else
        raise response.body
      end
    rescue => e
      puts "ERROR: #{e.response}"
      puts e.inspect
    end
  end

  desc 'POST Region Search'
  task region_search: :environment do
    # params:
    # commit (Proximity Search or Region Search)
    # region_id
    # region_feature_types

    # possible feature types = ['All', 'Building', 'District System', 'Region', 'Taxlot']

    params = {}
    params[:commit] = 'Region Search'
    params[:region_id] = '56be0287b02c308c03000b67'
    params[:region_feature_types] = ['Building']

    json_request = JSON.generate(params)

    begin
      request = RestClient::Resource.new('http://localhost:3000/api/search', user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      if response.code == 200
        puts "SUCCESS: #{response.body}"
      else
        raise response.body
      end
    rescue => e
      puts "ERROR: #{e.response}"
      puts e.inspect
    end
  end

  desc 'POST Proximity Search'
  task proximity_search: :environment do
    # params:
    # commit (Proximity Search or Region Search)
    # building_id
    # distance
    # proximity_feature_types

    # possible_types = ['All', 'Building', 'District System', 'Region', 'Taxlot']

    params = {}
    params[:commit] = 'Proximity Search'
    params[:building_id] = '56be0207b02c308c03000001'
    params[:distance] = 100
    params[:proximity_feature_types] = ['Taxlot']

    json_request = JSON.generate(params)

    begin
      request = RestClient::Resource.new('http://localhost:3000/api/search', user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      puts "RESPONSE: #{response.inspect}"
      if response.code == 200
        puts "SUCCESS: #{response.body}"
      else
        raise response.body
      end
    rescue => e
      puts "ERROR: #{e.response}"
      puts e.inspect
    end
  end
end
