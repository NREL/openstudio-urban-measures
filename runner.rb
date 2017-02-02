require 'rest-client'
require 'parallel'
require 'json'

# Runner creates all datapoints in a project, it then downloads max_datapoints number of osws, then runs all downloaded osws
class Runner

  def initialize(url, openstudio_exe, project_id, user_name, user_pwd, max_datapoints, num_parallel)
    @url = url
    @openstudio_exe = openstudio_exe
    @project_id = project_id   
    @user_name = user_name
    @user_pwd = user_pwd
    @max_datapoints = max_datapoints
    @num_parallel = num_parallel
    
    @project = get_project
    @project_name = @project[:name]
  end
  
  def update_measures
    measure_dir = File.join(File.dirname(__FILE__), "/measures")
    command = "'#{@openstudio_exe}' measure -t '#{measure_dir}'"
    puts command
    system(command)
  end
  
  def clear_results(datapoint_ids = [])
    puts "clear_results, datapoint_ids = #{datapoint_ids}"
    
    if datapoint_ids.empty?
      datapoint_ids = get_all_datapoint_ids
    end
    
    datapoint_ids.each do |datapoint_id|
      datapoint = {}
      datapoint[:id] = datapoint_id
      datapoint[:status] = nil
      datapoint[:results] = nil
      
      # DLM: todo, how to reset related files?

      params = {}
      params[:project_id] = @project_id
      params[:datapoint] = datapoint

      request = RestClient::Resource.new("#{@url}/api/datapoint.json", user: @user_name, password: @user_pwd)
      response = request.post(params, content_type: :json, accept: :json)    
    end
  end
  
  def get_project()
    puts "get_project"
    
    result = []
    
    request = RestClient::Resource.new("#{@url}/projects/#{@project_id}.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
    
    result = JSON.parse(response.body, :symbolize_names => true)

    return result[:project]
  end  
    
  def get_all_feature_ids(feature_type)
    puts "get_all_feature_ids, feature_type = #{feature_type}"
    result = []
    
    json_request = JSON.generate('types' => [feature_type], 'project_id' => @project_id)
    request = RestClient::Resource.new("#{@url}/api/export", user: @user_name, password: @user_pwd)
    response = request.post(json_request, content_type: :json, accept: :json)
    
    buildings = JSON.parse(response.body, :symbolize_names => true)
    buildings[:features].each do |building|
      result << building[:properties][:id]
    end

    return result
  end
  
  def get_all_workflow_ids(feature_type)
    puts "get_all_workflow_ids, feature_type = #{feature_type}"
    result = []
    
    request = RestClient::Resource.new("#{@url}/workflows.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
  
    workflows = JSON.parse(response.body, :symbolize_names => true)
    workflows.each do |workflow|
      if feature_type != workflow[:feature_type]
        puts "skipping workflow with feature_type '#{workflow[:feature_type]}', requested feature_type '#{feature_type}'"
        next
      end
      
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
  
  def get_all_scenario_ids()
    puts "get_all_scenario_ids"
    result = []
    
    request = RestClient::Resource.new("#{@url}/scenarios.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
  
    scenarios = JSON.parse(response.body, :symbolize_names => true)
    scenarios.each do |scenario|
      
      project_id = scenario[:project_id]
      if project_id == @project_id
        result << scenario[:id]
      else
        puts "skipping scenario #{scenario[:id]} since it is not associated with project #{@project_id}"
      end
    end
  
    puts "get_all_scenario_ids = #{result.join(',')}"
    return result
  end
  
  def get_all_datapoint_ids()
    puts "get_all_datapoint_ids"
    result = []
    
    request = RestClient::Resource.new("#{@url}/datapoints.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
  
    datapoints = JSON.parse(response.body, :symbolize_names => true)
    
    # sort building datapoints before district system ones
    datapoints.sort!{|a,b| a[:feature_type] <=> b[:feature_type]}
    
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
    puts "get_datapoint, building_id = #{building_id}, workflow_id = #{workflow_id}"
    # todo: DLM, needs to be generalized to take feature_id
    json_request = JSON.generate('workflow_id' => workflow_id, 'building_id' => building_id, 'project_id' => @project_id)
    request = RestClient::Resource.new("#{@url}/api/retrieve_datapoint", user: @user_name, password: @user_pwd)
    response = request.post(json_request, content_type: :json, accept: :json)
    
    datapoint = JSON.parse(response.body, :symbolize_names => true)
    return datapoint[:datapoint]
  end

   def get_datapoint_by_id(datapoint_id)
    puts "get_datapoint_by_id, datapoint_id = #{datapoint_id}"
    request = RestClient::Resource.new("#{@url}/datapoints/#{datapoint_id}.json", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)
    
    datapoint = JSON.parse(response.body, :symbolize_names => true)
    return datapoint[:datapoint]
  end
  
  def get_workflow(datapoint_id)
    puts "get_workflow, datapoint_id = #{datapoint_id}"
    puts "#{@url}/datapoints/#{datapoint_id}/instance_workflow.json"
    request = RestClient::Resource.new("#{@url}/datapoints/#{datapoint_id}/instance_workflow.json", user: @user_name, password: @user_pwd)
    begin
      response = request.get(content_type: :json, accept: :json)
    rescue => e
      puts e.response
    end

    workflow = JSON.parse(response.body, :symbolize_names => true)
    return workflow
  end

  def get_scenario(scenario_id)
    puts "get_scenario, scenario_id = #{scenario_id}"
    puts "#{@url}/scenarios/#{scenario_id}.json"
    request = RestClient::Resource.new("#{@url}/scenarios/#{scenario_id}.json", user: @user_name, password: @user_pwd)
    begin
      response = request.get(content_type: :json, accept: :json)
    rescue => e
      puts e.response
    end

    scenario = JSON.parse(response.body, :symbolize_names => true)
    return scenario[:scenario]
  end
  
  def get_results(scenario_id)
    puts "get_results, scenario_id = #{scenario_id}"
    request = RestClient::Resource.new("#{@url}/api/scenario_features.json?project_id=#{@project_id}&scenario_id=#{scenario_id}", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)

    results = JSON.parse(response.body, :symbolize_names => true)
    return results
  end
  
  # return a vector of directories to run
  def create_osws
    puts "create_osws"
    result = []
    
    # connect to database, get list of all datapoint ids
    all_datapoint_ids = get_all_datapoint_ids()

    puts "Project #{@project_name}"
    puts "#{all_datapoint_ids.size} datapoints"
    
    # loop over all combinations
    num_datapoints = 1
    all_datapoint_ids.each do |datapoint_id|
    
      datapoint = get_datapoint_by_id(datapoint_id)
      
      # DLM: TODO: skipp running district system datapoints until all buildings are run
      
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
      puts "Saving Datapoint #{datapoint}"
      
      result << create_osw(datapoint_id)
      
      num_datapoints += 1
      if @max_datapoints < num_datapoints
        return result
      end
      
    end
    
    return result
  end

  def create_osw(datapoint_id)
    puts "create_osw, datapoint_id = #{datapoint_id}"
    datapoint = get_datapoint_by_id(datapoint_id)

    # datapoint is not run, get the workflow
    # this is the merged workflow with the building properties merged in to the template workflow
    workflow = get_workflow(datapoint_id)
    
    building_workflow_id = nil
    if workflow[:feature_type] == "District System"
      building_workflow_ids = get_all_workflow_ids("Building")
      building_workflow_id = building_workflow_ids[0]
    end
    
    workflow[:steps].each do |step|
      arguments = step[:arguments]
      arguments.each_key do |name|

        if name == 'city_db_url'.to_sym
          arguments[name] = @url
        end
        
        if name == 'building_workflow_id'.to_sym
          arguments[name] = building_workflow_id
        end

        # work around for https://github.com/NREL/OpenStudio-workflow-gem/issues/32
        if name == 'weather_file_name'.to_sym
          workflow[:weather_file] = arguments[name]
        end
      end
    end
    
    workflow[:file_paths] = ["./../../../files", "./../../../adapters", "./../../../weather"]
    workflow[:measure_paths] = ["./../../../measures"]
    workflow[:run_options] = {output_adapter:{custom_file_name:"./../../../adapters/output_adapter.rb", class_name:"CityDB",options:{url:@url,datapoint_id:datapoint_id,project_id:@project_id}}}

    # save workflow
    osw_dir = File.join(File.dirname(__FILE__), "/run/#{@project_name}/datapoint_#{datapoint_id}")
    FileUtils.rm_rf(osw_dir)
    FileUtils.mkdir_p(osw_dir)
 
    osw_path = "#{osw_dir}/in.osw"
    puts "saving osw #{osw_path}"
    File.open(osw_path, 'w') do |file|
      file << JSON.pretty_generate(workflow)
    end
            
    return osw_dir
  end
  
  def run_osws(dirs)
    puts "run_osws, dirs = #{dirs}"
    #dirs = Dir.glob("./run/*")
    
    Parallel.each(dirs, in_threads: [@max_datapoints,@num_parallel].min) do |osw_dir|
      
      md = /datapoint_(.*)/.match(osw_dir)
      next if !md
      
      osw_path = File.join(osw_dir, "in.osw")
      
      datapoint_id = md[1].gsub('/','')
      
      command = "'#{@openstudio_exe}' run -w '#{osw_path}'"
      puts command
      system(command)
    end
  end
  
  def save_results
    puts "save_results"
    all_scenario_ids = get_all_scenario_ids()
    
    all_scenario_ids.each do |scenario_id|
      scenario = get_scenario(scenario_id)
      scenario_name = scenario[:name]
      results_path = File.join(File.dirname(__FILE__), "/run/#{@project_name}/#{scenario_name}.geojson")
      
      if !File.exists?(results_path)
        results = get_results(scenario_id)
        
        File.open(results_path, 'w') do |file|
          file << JSON.pretty_generate(results)
        end
      end
    end
    
  end
  
end
