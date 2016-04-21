require 'rest-client'
require 'json'

class Runner

  def initialize
    @url = 'http://localhost:3000'
    @project_id = '570d6b12c44c8d1e3800030b'
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'
  end
    
  def get_all_building_ids()
    result = []
    
    json_request = JSON.generate('types' => ['Building'], 'project_id' => @project_id)
    request = RestClient::Resource.new("#{@url}/api/export", user: @user_name, password: @user_pwd)
    response = request.post(json_request, content_type: :json, accept: :json)
    
    buildings = JSON.parse(response.body, :symbolize_names => true)
    buildings[:features].each do |building|
      result << building[:properties][:id]
    end

    return result
  end

  def get_all_workflow_ids()
    result = []
    
    request = RestClient::Resource.new("#{@url}/workflows.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
  
    workflows = JSON.parse(response.body, :symbolize_names => true)
    workflows.each do |workflow|

      project_id = workflow[:project_id]
      if project_id == @project_id
        result << workflow[:id]
      else
        puts "skipping workflow #{workflow[:id]} since it is not associated with project #{@project_id}"
      end
    end
  
    return result
  end

  def get_datapoint(building_id, workflow_id)
    json_request = JSON.generate('workflow_id' => workflow_id, 'building_id' => building_id, 'project_id' => @project_id)
    request = RestClient::Resource.new("#{@url}/api/retrieve_datapoint", user: @user_name, password: @user_pwd)
    response = request.post(json_request, content_type: :json, accept: :json)
    
    datapoint = JSON.parse(response.body, :symbolize_names => true)
    return datapoint[:datapoint]
  end

  def get_workflow(datapoint_id)
    puts "#{@url}/datapoints/#{datapoint_id}/instance_workflow.json"
    
    request = RestClient::Resource.new("#{@url}/datapoints/#{datapoint_id}/instance_workflow.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
    
    puts "datapoint_id = #{datapoint_id}"
    puts response.body
    fail "hi"
    workflow = JSON.parse(response.body, :symbolize_names => true)
    return workflow
  end

  def run(workflow)

  end

  def post_datapoint_success(workflow)

  end

  def post_datapoint_failed(workflow)

  end
  
  def create_osws
    # connect to database, get list of all building and workflow ids
    all_building_ids = get_all_building_ids
    all_workflow_ids = get_all_workflow_ids
    
    puts "#{all_building_ids.size} buildings"
    puts "#{all_workflow_ids.size} workflows"

    # loop over all combinations
    all_building_ids.each do |building_id|
      all_workflow_ids.each do |workflow_id|
        
        # get data point for each pair of building_id, workflow_id
        # data point is created if it doesn't already exist
        datapoint = get_datapoint(building_id, workflow_id)
        datapoint_id = datapoint[:id]
        
        # check if this already has dencity results or is queued to run
        if !datapoint[:dencity_id].nil? || datapoint[:status] == "Queued"
          next
        end
        
        # datapoint is not run, get the workflow
        # this is the merged workflow with the building properties merged in to the template workflow
        workflow = get_workflow(datapoint_id)

        # save workflow
        osw_dir = File.join(File.dirname(__FILE__), "/run/datapoint_#{datapoint_id}/")
        FileUtils.rm_rf(osw_dir)
        FileUtils.mkdir_p(osw_dir)

        osw_path = "#{osw_dir}/in.osw"
        File.open(osw_path, 'w') do |file|
          file << workflow
        end
        
      end
    end
  end
  
  def run_osws
    Dir.glob("./runs/*.osw").each do |osw_path|

      workflow = JSON::load(osw_path)

      begin
        # run the osw
        run(workflow)
        
        dencity_id = nil
        
        # things worked, post back to the database that this datapoint is done and point to dencity id
        post_datapoint_success(workflow, dencity_id)
      rescue
      
        # things broke, post back to the database that this datapoint failed
        post_datapoint_failed(workflow)
      end
      
    end
  end
end

runner = Runner.new
runner.create_osws



