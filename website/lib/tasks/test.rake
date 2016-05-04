require 'rest-client'

namespace :testing do

  def get_or_create_project(name = 'test_project')
    project = Project.where(name: name).first
    if project.nil?
      user = User.first
      # DLM you could make a new user here?
      fail if user.nil?
      
      project = Project.new(name: name, display_name: name, user: user)
      project.save
    end
    return project
  end

  # Test batch_upload
  desc 'Batch upload features  (api/batch_upload)'
  task batch_upload_features: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'

    # filename = "#{Rails.root}/data/san_francisco_bldg_footprints_4326.geojson"
    filename = "#{Rails.root}/data/US_CA_Tract_06075010300.clean.geojson"
    #filename = "#{Rails.root}/lib/test.geojson"

    # set this for testing
    project = get_or_create_project
    project_id = project.id.to_s
    
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
    project = get_or_create_project
    project_id = project.id.to_s

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
  
  # Test project_search
  desc 'Search for project (api/project_search)'
  task project_search: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'
    
    #Project.destroy_all
    
    project_name = 'test_project'
    project = get_or_create_project(project_name)

    # search for a project by name
    json_request = JSON.generate({'name' => project_name})
    
    # search across all projects
    #json_request = JSON.generate({})

    # puts "POST http://localhost:3000/api/project_search, parameters: #{json_request}"
    begin
      request = RestClient::Resource.new('http://localhost:3000/api/project_search', user: @user_name, password: @user_pwd)
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

    filename = "#{Rails.root}/data/baseline.osw"

    # set this for testing
    project = get_or_create_project
    project_id = project.id.to_s

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
    
    # set this for testing
    project = get_or_create_project
    project_id = project.id.to_s    

    # only works after saving a structure, so get a valid one
    workflow = project.workflows.first
    workflow_id = workflow.id.to_s

    file = File.open("#{Rails.root}/data/baseline.zip", 'rb')
    the_file = Base64.strict_encode64(file.read)
    file.close
    # file_data param
    file_data = {}
    file_data['file_name'] = 'baseline.zip'
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

  # Test create datapoints
  desc 'GET create_datapoints'
  task create_datapoints: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'

    # set this for testing
    project = get_or_create_project
    project_id = project.id.to_s
    
    workflow = project.workflows.first
    workflow_id = workflow.id

    begin
      request = RestClient::Resource.new("http://localhost:3000/workflows/#{workflow_id}/create_datapoints", user: @user_name, password: @user_pwd)
      response = request.get(content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end
    
    datapoint = workflow.datapoints.first
    datapoint_id = datapoint.id
    
    begin
      request = RestClient::Resource.new("http://localhost:3000/datapoints/#{datapoint_id}/instance_workflow.json", user: @user_name, password: @user_pwd)
      response = request.get(content_type: :json, accept: :json)
      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
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
    building = project.buildings.first_or_create

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

  # Test import workflow_file
  desc 'POST datapoint_file'
  task post_datapoint_file: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'
    
    # set this for testing
    project = Project.first_or_create
    project_id = project.id.to_s    

    datapoint = project.datapoints.first

    file = File.open("#{Rails.root}/data/test.csv", 'rb')
    the_file = Base64.strict_encode64(file.read)
    file.close
    # file_data param
    file_data = {}
    file_data['file_name'] = 'datapoint_file_test.csv'
    file_data['file'] = the_file

    json_request = JSON.generate('datapoint_id' => datapoint.id.to_s, 'file_data' => file_data)
    # puts "POST http://<user>:<pwd>@<base_url>/api/v1/related_file, parameters: #{json_request}"

    begin
      request = RestClient::Resource.new('http://localhost:3000/api/datapoint_file', user: @user_name, password: @user_pwd)
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

   # get workflow file by datapoint_id and file_name
  desc 'GET datapoint file'
  task retrieve_datapoint_file: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123' 

    proj = Project.first

    dp = Datapoint.find('57156befb02c3075270001a9')
    filename = 'datapoint_file_test.csv'

    begin
      request = RestClient::Resource.new("http://localhost:3000", user: @user_name, password: @user_pwd)
      response = request["api/retrieve_datapoint_file?datapoint_id=#{dp.id.to_s}&file_name=#{filename}"].get(content_type: :json, accept: :json)

      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end

  end

  # delete datapoint file by datapoint_id and file_name
  desc 'DELETE datapoint file'
  task delete_datapoint_file: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123' 

    proj = Project.first

    dp = Datapoint.find('57156befb02c3075270001a9')
    filename = 'datapoint_file_test.csv'

    begin
      request = RestClient::Resource.new("http://localhost:3000", user: @user_name, password: @user_pwd)
      response = request["api/delete_datapoint_file?datapoint_id=#{dp.id.to_s}&file_name=#{filename}"].get(content_type: :json, accept: :json)

      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end

  end


  # get instance workflow for a datapoint
  desc 'GET instance_workflow'
  task instance_workflow: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'

    datapoint = Datapoint.first
    puts "Datapoint: #{datapoint.id.to_s}"
    begin
      request = RestClient::Resource.new("http://localhost:3000", user: @user_name, password: @user_pwd)
      response = request["datapoints/#{datapoint.id.to_s}/instance_workflow"].get(content_type: :json, accept: :json)

      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end
  end

  # get workflow file by datapoint_id or workflow_id
  desc 'GET workflow file'
  task retrieve_workflow_file: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123' 

    proj = Project.first

    dp = proj.datapoints.first

    wf = dp.workflow

    begin
      request = RestClient::Resource.new("http://localhost:3000", user: @user_name, password: @user_pwd)
      response = request["api/retrieve_workflow_file?datapoint_id=#{dp.id.to_s}"].get(content_type: :json, accept: :json)

      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end

  end

  # get workflow datapoints
  desc 'GET workflow datapoints'
  task retrieve_workflow_datapoints: :environment do 
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123' 

    proj = Project.first
    wf = proj.workflows.first

    begin
      request = RestClient::Resource.new("http://localhost:3000", user: @user_name, password: @user_pwd)
      response = request["workflows/#{wf.id.to_s}/datapoints"].get(content_type: :json, accept: :json)

      puts "Status: #{response.code}"
      puts "SUCCESS: #{response.body}"
    rescue => e
      puts "ERROR: #{e.response}"
    end
  end

  # get buildings by workflow
  desc 'GET workflow buildings'
  task workflow_buildings: :environment do
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123' 

    proj = Project.first
    wf = proj.workflows.first
    puts "Request: api/workflow_buildings?project_id=#{proj.id.to_s}&workflow_id=#{wf.id.to_s}"

    begin
      request = RestClient::Resource.new("http://localhost:3000", user: @user_name, password: @user_pwd)
      response = request["api/workflow_buildings?project_id=#{proj.id.to_s}&workflow_id=#{wf.id.to_s}"].get(content_type: :json, accept: :json)

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
    project = get_or_create_project
    project_id = project.id.to_s
    
    params = {}
    params[:commit] = 'Region Search'
    params[:region_id] = project.regions.first.id.to_s
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
    project = get_or_create_project
    project_id = project.id.to_s
    
    params = {}
    params[:commit] = 'Proximity Search'
    params[:building_id] = project.buildings.first.id.to_s
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
    project = get_or_create_project
    project_id = project.id.to_s

    # possible_types = ['All', 'Building', 'District System', 'Region', 'Taxlot']
    bldg = project.buildings.first

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
