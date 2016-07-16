require 'rest-client'
require 'parallel'
require 'json'

# Runner creates all datapoints in a project, it then downloads max_datapoints number of osws, then runs all downloaded osws
class Runner

  def initialize(url, project_id, user_name, user_pwd, max_datapoints, num_parallel)
    @url = url
    @project_id = project_id   
    @user_name = user_name
    @user_pwd = user_pwd
    @max_datapoints = max_datapoints
    @num_parallel = num_parallel
    
    @project = get_project
    @project_name = @project[:name]
  end
  
  def clear_results(datapoint_ids = [])
    if datapoint_ids.empty?
      datapoint_ids = get_all_datapoint_ids
    end
    
    datapoint_ids.each do |datapoint_id|
      datapoint = {}
      datapoint[:id] = datapoint_id
      datapoint[:status] = nil
      datapoint[:results] = nil

      params = {}
      params[:project_id] = @project_id
      params[:datapoint] = datapoint

      request = RestClient::Resource.new("#{@url}/api/datapoint", user: @user_name, password: @user_pwd)
      response = request.post(params, content_type: :json, accept: :json)    
    end
  end
  
  def get_project()
    result = []
    
    request = RestClient::Resource.new("#{@url}/projects/#{@project_id}.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
    
    result = JSON.parse(response.body, :symbolize_names => true)

    return result[:project]
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
  
    puts "get_all_workflow_ids = #{result.join(',')}"
    return result
  end
  
  def get_all_datapoint_ids()
    result = []
    
    request = RestClient::Resource.new("#{@url}/datapoints.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
  
    datapoints = JSON.parse(response.body, :symbolize_names => true)
    datapoints.each do |datapoint|

      project_id = datapoint[:project_id]
      if project_id == @project_id
        result << datapoint[:id]
      else
        puts "skipping datapoint #{datapoint[:id]} since it is not associated with project #{@project_id}"
      end
    end
  
    puts "get_all_datapoint_ids = #{result.join(',')}"
    return result
  end
  
  def get_datapoint(building_id, workflow_id)
    json_request = JSON.generate('workflow_id' => workflow_id, 'building_id' => building_id, 'project_id' => @project_id)
    request = RestClient::Resource.new("#{@url}/api/retrieve_datapoint", user: @user_name, password: @user_pwd)
    response = request.post(json_request, content_type: :json, accept: :json)
    
    datapoint = JSON.parse(response.body, :symbolize_names => true)
    return datapoint[:datapoint]
  end

   def get_datapoint_by_id(datapoint_id)
    request = RestClient::Resource.new("#{@url}/datapoints/#{datapoint_id}.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
    
    datapoint = JSON.parse(response.body, :symbolize_names => true)
    return datapoint[:datapoint]
  end
  
  def get_workflow(datapoint_id)
    request = RestClient::Resource.new("#{@url}/datapoints/#{datapoint_id}/instance_workflow.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)

    workflow = JSON.parse(response.body, :symbolize_names => true)
    return workflow
  end
  
  def get_results(workflow_id)
    request = RestClient::Resource.new("#{@url}/api/workflow_buildings.json?project_id=#{@project_id}&workflow_id=#{workflow_id}", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)

    results = JSON.parse(response.body, :symbolize_names => true)
    return results
  end
  
  # return a vector of directories to run
  def create_osws
    result = []
    
    # connect to database, get list of all building and workflow ids
    all_building_ids = get_all_building_ids
    all_workflow_ids = get_all_workflow_ids
    
    puts "Project #{@project_name}"
    puts "#{all_building_ids.size} buildings"
    puts "#{all_workflow_ids.size} workflows"

    # loop over all combinations
    num_datapoints = 1
    all_building_ids.each do |building_id|
      all_workflow_ids.each do |workflow_id|

        # get data point for each pair of building_id, workflow_id
        # data point is created if it doesn't already exist
        datapoint = get_datapoint(building_id, workflow_id)
        datapoint_id = datapoint[:id]
        
        # see if datapoint needs to be run
        if datapoint[:status] 
          if datapoint[:status] == "Started"
            puts "Skipping Started Datapoint"
            next
          elsif datapoint[:status] == "Complete"
            puts "Skipping Complete Datapoint"
            next
          elsif datapoint[:status] == "Failed"
            puts "Skipping Failed Datapoint"
            next
          end
        end
        puts "Saving Datapoint"
        
        result << create_osw(datapoint_id)
        
        num_datapoints += 1
        if @max_datapoints < num_datapoints
          return result
        end
        
      end
    end
    
    return result
  end

  def create_osw(datapoint_id)

    datapoint = get_datapoint_by_id(datapoint_id)
    datapoint_id = datapoint[:id]
    
    # datapoint is not run, get the workflow
    # this is the merged workflow with the building properties merged in to the template workflow
    workflow = get_workflow(datapoint_id)
    
    workflow[:steps].each do |step|
      arguments = step[:arguments]
      arguments.each_key do |name|

        if name == 'city_db_url'.to_sym
          arguments[name] = @url
        end
        
        # work around for https://github.com/NREL/OpenStudio-workflow-gem/issues/32
        if name == 'weather_file_name'.to_sym
          workflow[:weather_file] = arguments[name]
        end
      end
    end

    # save workflow
    osw_dir = File.join(File.dirname(__FILE__), "/run/#{@project_name}/datapoint_#{datapoint_id}")
    FileUtils.rm_rf(osw_dir)
    FileUtils.mkdir_p(osw_dir)
 
    osw_path = "#{osw_dir}/in.osw"
    File.open(osw_path, 'w') do |file|
      file << JSON.pretty_generate(workflow)
    end
            
    return osw_dir
  end
  
  def run_osws(dirs)
  
    #dirs = Dir.glob("./run/*")
    
    Parallel.each(dirs, in_threads: [@max_datapoints,@num_parallel].min) do |osw_dir|
      
      md = /datapoint_(.*)/.match(osw_dir)
      next if !md
      
      osw_path = File.join(osw_dir, "in.osw")
      
      datapoint_id = md[1].gsub('/','')
      
      command = "bundle exec ruby run.rb '#{osw_path}' '#{@url}' '#{datapoint_id}' '#{@project_id}'"
      puts command
      system(command)
    end
  end
  
  def save_results
  
    all_workflow_ids = get_all_workflow_ids
    
    all_workflow_ids.each do |workflow_id|
      results_path = File.join(File.dirname(__FILE__), "/run/#{@project_name}/workflow_#{workflow_id}.geojson")
      
      if !File.exists?(results_path)
        results = get_results(workflow_id)
        
        File.open(results_path, 'w') do |file|
          file << JSON.pretty_generate(results)
        end
      end
    end
    
  end
  
end
