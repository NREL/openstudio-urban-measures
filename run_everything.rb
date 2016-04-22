require 'rest-client'
require 'parallel'
require 'json'

class Runner

  def initialize
    @url = 'http://localhost:3000'
    @project_id = '570d6b12c44c8d1e3800030b'
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'
    @max_buildings = Float::INFINITY
    @max_buildings = 4
    @num_parallel = 4
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
    request = RestClient::Resource.new("#{@url}/datapoints/#{datapoint_id}/instance_workflow.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)

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
    num_buildings = 0
    all_building_ids.each do |building_id|
      
      num_buildings += 1
      break if @max_buildings < num_buildings
    
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
          file << JSON.generate(workflow)
        end
        
      end
    end
  end
  
  def run_osws
  
    dirs = Dir.glob("./run/*")
    
    Parallel.each(dirs, in_threads: @num_parallel) do |osw_dir|
      
      md = /datapoint_(.*)/.match(osw_dir)
      next if !md
      
      osw_path = File.join(osw_dir, "in.osw")
      
      datapoint_id = md[1]
      
      command = "ruby run.rb '#{osw_path}' '#{@url}' '#{datapoint_id}'"
      puts command
      system(command)
    end
  end
end

runner = Runner.new
#runner.create_osws
runner.run_osws


