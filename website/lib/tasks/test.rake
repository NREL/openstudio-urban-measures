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

    # set this for testing
    project_id = Project.first_or_create.id.to_s
    
    json_file = MultiJson.load(File.read(filename))
    json_request = JSON.generate('data' => json_file, 'project_id' => project_id)

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
    
    # set this for testing
    project_id = Project.first_or_create.id.to_s

    json_request = JSON.generate('types' => types, 'project_id' => project_id)

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

    # set this for testing
    project_id = Project.first_or_create.id.to_s

    json_file = MultiJson.load(File.read(filename))
    json_request = JSON.generate('workflow' => json_file, 'project_id' => project_id)

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
    
    # DLM: Kat, shouldn't we have to post the workflow to a project?
    project_id = Project.first_or_create.id.to_s

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

# Test import datapoint
  desc 'POST datapoint'
  task post_datapoint: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'

    # set this for testing
    project = Project.first_or_create
    workflow = project.workflows.first_or_create
    building = project.buildings.first_or_create

    datapoint = {}
    datapoint[:workflow_id] = workflow.id.to_s
    datapoint[:building_id] = building.id.to_s
    datapoint[:status] = 'test api'

    json_request = JSON.generate('datapoint' => datapoint, 'project_id' => project.id.to_s)

    begin
      request = RestClient::Resource.new('http://localhost:3000/api/datapoint', user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end
  end

  # Test retrieve (or create) datapoint
  desc 'GET datapoint'
  task retrieve_datapoint: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'

    # set this for testing
    project = Project.first_or_create
    workflow = project.workflows.first_or_create
    #building = project.buildings.first_or_create
    building = Building.find('571565e6b02c30752700016b')

    json_request = JSON.generate('workflow_id' => workflow.id.to_s, 'building_id' => building.id.to_s, 'project_id' => project.id.to_s)

    begin
      request = RestClient::Resource.new('http://localhost:3000/api/retrieve_datapoint', user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end
  end


  desc 'POST Region Search'
  task region_search: :environment do
    # params:
    # commit (Proximity Search or Region Search)
    # region_id
    # region_feature_types

    # possible feature types = ['All', 'Building', 'District System', 'Region', 'Taxlot']

    # DLM: Kat, shouldn't we have to get the region from the project?
    project_id = Project.first_or_create.id.to_s
    
    params = {}
    params[:commit] = 'Region Search'
    params[:region_id] = Region.first.id.to_s # region ID # DLM: Kat, shouldn't this have to get the region from the project?
    params[:region_feature_types] = ['Building']
    params[:project_id] = project_id

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
    
    # DLM: Kat, shouldn't we have to get the building from the project?
    project_id = Project.first_or_create.id.to_s
    
    params = {}
    params[:commit] = 'Proximity Search'
    params[:building_id] = Building.first.id.to_s
    params[:distance] = 100
    params[:proximity_feature_types] = ['Taxlot']
    params[:project_id] = project_id

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

  desc 'POST Search by ID'
  task search_by_id: :environment do
    # params:
    # commit (Search)
    # source_id
    # source_name
    # feature_types
    
    # DLM: Kat, shouldn't we have to get the building from the project?
    project_id = Project.first_or_create.id.to_s

    # possible_types = ['All', 'Building', 'District System', 'Region', 'Taxlot']
    bldg = Building.first

    params = {}
    params[:commit] = 'Search'
    params[:source_id] = bldg.source_id.to_s
    params[:source_name] = bldg.source_name
    params[:feature_types] = ['Building']
    params[:project_id] = project_id

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
