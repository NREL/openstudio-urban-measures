require 'rest-client'
require 'parallel'
require 'json'

class Runner

  def initialize
    @url = 'http://localhost:3000'
    #@url = 'http://insight4.hpc.nrel.gov:8081'
    @project_id = '572cf0a9c44c8d2290000002'
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'
    @max_datapoints = Float::INFINITY
    @max_datapoints = 2
    @num_parallel = 7
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
  
  def get_results(workflow_id)
    request = RestClient::Resource.new("#{@url}/api/workflow_buildings.json?project_id=#{@project_id}&workflow_id=#{workflow_id}", user: @user_name, password: @user_pwd)
    response = request.get(content_type: :json, accept: :json)

    results = JSON.parse(response.body, :symbolize_names => true)
    return results
  end
  
  # return a vector of directories to run
  def create_osws
    result = []
    
    project = get_project
    project_name = project[:name]
    
    # connect to database, get list of all building and workflow ids
    all_building_ids = get_all_building_ids
    all_workflow_ids = get_all_workflow_ids
    
    puts "Project #{project_name}"
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
            #puts "Skipping Started Datapoint"
            #next
          elsif datapoint[:status] == "Complete"
            puts "Skipping Complete Datapoint"
            next
          elsif datapoint[:status] == "Failed"
            #puts "Skipping Failed Datapoint"
            #next
          end
        end
        puts "Saving Datapoint"
        
        # datapoint is not run, get the workflow
        # this is the merged workflow with the building properties merged in to the template workflow
        workflow = get_workflow(datapoint_id)
        
        workflow[:steps].each do |step|
          step[:arguments].each do |argument|
            if argument[:name] == 'city_db_url'
              argument[:value] = @url
            end
            
            # work around for https://github.com/NREL/OpenStudio-workflow-gem/issues/32
            if argument[:name] == 'weather_file_name'
              workflow[:weather_file] = argument[:value]
            end
          end
        end

        # save workflow
        osw_dir = File.join(File.dirname(__FILE__), "/run/#{project_name}/datapoint_#{datapoint_id}/")
        FileUtils.rm_rf(osw_dir)
        FileUtils.mkdir_p(osw_dir)
        result << osw_dir

        osw_path = "#{osw_dir}/in.osw"
        File.open(osw_path, 'w') do |file|
          file << JSON.pretty_generate(workflow)
        end
        
        num_datapoints += 1
        if @max_datapoints < num_datapoints
          return result
        end
        
      end
    end
    
    return result
  end
  
  def run_osws(dirs)
  
    #dirs = Dir.glob("./run/*")
    
    Parallel.each(dirs, in_threads: [@max_datapoints,@num_parallel].min) do |osw_dir|
      
      md = /datapoint_(.*)/.match(osw_dir)
      next if !md
      
      osw_path = File.join(osw_dir, "in.osw")
      
      datapoint_id = md[1].gsub('/','')
      
      command = "ruby run.rb '#{osw_path}' '#{@url}' '#{datapoint_id}' '#{@project_id}'"
      puts command
      system(command)
    end
  end
  
  def save_results
  
    project = get_project
    project_name = project[:name]
    
    all_workflow_ids = get_all_workflow_ids
    
    all_workflow_ids.each do |workflow_id|
      results = get_results(workflow_id)
      
      results_path = File.join(File.dirname(__FILE__), "/run/#{project_name}/workflow_#{workflow_id}.geojson")
      File.open(results_path, 'w') do |file|
        file << JSON.pretty_generate(results)
      end
    end
    
  end
  
end

runner = Runner.new
dirs = runner.create_osws
runner.run_osws(dirs)
runner.save_results
