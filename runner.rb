require 'rest-client'
require 'parallel'
require 'json'
require 'base64'
require 'csv'

require_relative 'map_properties'

# Runner creates all datapoints in a project, it then downloads max_datapoints number of osws, then runs all downloaded osws
class Runner

  def initialize(url, openstudio_exe, openstudio_measures, openstudio_files, project_id, user_name, user_pwd, max_datapoints, num_parallel)
    @url = url
    @openstudio_exe = openstudio_exe
    @openstudio_measures = openstudio_measures
    @openstudio_files = openstudio_files
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
      
      json_request = JSON.generate('project_id' => @project_id, 'datapoint' => datapoint)
      
      existing_datapoint = get_datapoint(datapoint_id)
      puts "existing_datapoint = #{existing_datapoint}"
      if existing_datapoint[:datapoint_files]
        existing_datapoint[:datapoint_files].each do |file|
          filename = file[:file_name]
          puts "deleting file #{filename} for datapoint #{datapoint_id}"
          
          request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
          response = request["/api/delete_datapoint_file?datapoint_id=#{datapoint_id}&file_name=#{filename}"].get(content_type: :json, accept: :json)
          
        end
      end

      request = RestClient::Resource.new("#{@url}/api/datapoint", user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)    
    end
  end
  
  def get_project()
    puts "get_project"
    
    result = []
    
    request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
    response = request["/api/project?project_id=#{@project_id.to_s}"].get(content_type: :json, accept: :json)
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
    
    request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
    response = request["/api/workflows?project_id=#{@project_id.to_s}"].get(content_type: :json, accept: :json)
  
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
    
    request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
    response = request["/api/scenarios?project_id=#{@project_id.to_s}"].get(content_type: :json, accept: :json)
  
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
    
    request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
    response = request["/api/datapoints?project_id=#{@project_id.to_s}"].get(content_type: :json, accept: :json)
  
    datapoints = JSON.parse(response.body, :symbolize_names => true)
    
    # sort building datapoints before district system ones
    feature_types = ['Building', 'District System']
    datapoints.sort!{|a,b| feature_types.index(a[:feature_type]) <=> feature_types.index(b[:feature_type])}
    
    # make an array of datapoint IDs only
    result = datapoints.map{|x| x[:id]}
  
    puts "get_all_datapoint_ids = #{result.join(',')}"
    return result
  end
  
  def get_or_create_datapoint(feature_id, option_set_id, scenario_id)
    puts "get_or_create_datapoint, feature_id = #{feature_id}, option_set_id = #{option_set_id}, scenario_id = #{scenario_id}"
    
    json_request = JSON.generate('feature_id' => feature_id, 'option_set_id' => option_set_id, 'scenario_id' => scenario_id, 'project_id' => @project_id)
    request = RestClient::Resource.new("#{@url}/api/retrieve_datapoint", user: @user_name, password: @user_pwd)
    response = request.post(json_request, content_type: :json, accept: :json)
    
    datapoint = JSON.parse(response.body, :symbolize_names => true)
    return datapoint[:datapoint]
  end

   def get_datapoint(datapoint_id)
    puts "get_datapoint, datapoint_id = #{datapoint_id}"
    request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
    response = request["/api/retrieve_datapoint?project_id=#{@project_id}&datapoint_id=#{datapoint_id}"].get(content_type: :json, accept: :json)
    
    datapoint = JSON.parse(response.body, :symbolize_names => true)
    return datapoint[:datapoint]
  end
  
  def get_option_set(option_set_id)
    puts "get_option_set, option_set_id = #{option_set_id}"

    request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
    response = request["/api/retrieve_option_set?project_id=#{@project_id}&option_set_id=#{option_set_id}"].get(content_type: :json, accept: :json)
    
    datapoint = JSON.parse(response.body, :symbolize_names => true)
    return datapoint[:option_set]
  end
  
  def get_feature(feature_id)
    puts "feature_id, feature_id = #{feature_id}"
    request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
    response = request["/api/feature?project_id=#{@project_id}&feature_id=#{feature_id}"].get(content_type: :json, accept: :json)
    
    feature = JSON.parse(response.body, :symbolize_names => true)
    return feature
  end
  
  def get_scenario(scenario_id)
    puts "get_scenario, scenario_id = #{scenario_id}"
    puts "#{@url}/scenarios/#{scenario_id}.json"
    request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
    begin
      response = request["/api/retrieve_scenario?project_id=#{@project_id}&scenario_id=#{scenario_id}"].get(content_type: :json, accept: :json)
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
  
  def get_detailed_results(datapoint_id)
    puts "get_detailed_results, datapoint_id = #{datapoint_id}"
    request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
    response = request["/api/retrieve_datapoint?project_id=#{@project_id}&datapoint_id=#{datapoint_id}"].get(content_type: :json, accept: :json)

    datapoint = JSON.parse(response.body, :symbolize_names => true)[:datapoint]

    datapoint_files = datapoint[:datapoint_files]
    if datapoint_files
      datapoint_files.each do |datapoint_file|
        if /datapoint_reports_report\.csv/.match( datapoint_file[:file_name] )
          file_name = datapoint_file[:file_name]
          file_id = datapoint_file[:_id][:$oid]

          request = RestClient::Resource.new("#{@url}/api/retrieve_datapoint_file.json?project_id=#{@project_id}&datapoint_id=#{datapoint_id}&file_name=#{file_name}", user: @user_name, password: @user_pwd)
          response = request.get(content_type: :json, accept: :json)

          file_data = JSON.parse(response.body, :symbolize_names => true)[:file_data]
          file = Base64.strict_decode64(file_data[:file])

          return file
        end
      end
    end    
    
    return nil
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
    
      datapoint = get_datapoint(datapoint_id)
      
      # DLM: TODO: skip running district system datapoints until all buildings are run
      
      # see if datapoint needs to be run
      if datapoint[:status] 
        if datapoint[:status] == "Started"
          puts "Skipping Started Datapoint"
          next
        elsif datapoint[:status] == "Complete"
          puts "Skipping Complete Datapoint"
          next
        elsif datapoint[:status] == "Failed"
          #puts "Skipping Failed Datapoint"
          #next
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
    
    datapoint = get_datapoint(datapoint_id) # format scenario_ids as array of strings
    feature_id = datapoint[:feature_id]
    feature_type = datapoint[:feature_type]
    option_set_id = datapoint[:option_set_id]

    workflow = get_option_set(option_set_id)
    feature = get_feature(feature_id)
    project = get_project()
    
    # if feature_type, set scenario_id
    scenario_id = nil
    if feature_type == "District System"
      scenario_id = datapoint[:scenario_ids].first
    end
    
    puts "option_set_id = #{option_set_id}"
    puts "workflow = #{workflow}"
    puts "feature_id = #{feature_id}"
    puts "feature_type = #{feature_type}"
    puts "feature = #{feature}"
    puts "project = #{project}"
    puts "scenario_id = #{scenario_id}"
    
    if project[:properties].nil?
      project[:properties] = {}
    end
    
    workflow.delete(:datapoints)

    workflow = configure_workflow(workflow, feature, project)
    
    workflow[:steps].each do |step|
      arguments = step[:arguments]
      arguments.each_key do |name|

        if name == :city_db_url
          arguments[name] = @url
        end
        
        if name == :project_id
          arguments[name] = @project_id
        end
        
        if name == :scenario_id
          arguments[name] = scenario_id
        end
        
        if name == :feature_id
          arguments[name] = feature_id
        end
        
        if name == :datapoint_id
          arguments[name] = datapoint_id
        end
        
        # work around for https://github.com/NREL/OpenStudio-workflow-gem/issues/32
        if name == :weather_file_name
          workflow[:weather_file] = arguments[name]
        end
      end
    end
    
    workflow[:file_paths] = @openstudio_files
    workflow[:measure_paths] = @openstudio_measures
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
      
      # ok to put user name and password in environment variables?
      command = "'#{@openstudio_exe}' run -w '#{osw_path}'"
      puts command
      system({"URBANOPT_USERNAME" => @user_name, "URBANOPT_PASSWORD" => @user_pwd}, command)
    end
  end
  
  def save_results(save_datapoint_files = false)
    puts "save_results"
    all_scenario_ids = get_all_scenario_ids()
    
    all_scenario_ids.each do |scenario_id|
      scenario = get_scenario(scenario_id)
      scenario_name = scenario[:name]
      results_path = File.join(File.dirname(__FILE__), "/run/#{@project_name}/#{scenario_name}.geojson")
      
      if !File.exists?(results_path)
        results = get_results(scenario_id)
        
        results_dir = File.dirname(results_path)
        if !File.exists?(results_dir)
          FileUtils.mkdir_p(results_dir)
        end
        
        File.open(results_path, 'w') do |file|
          file << JSON.pretty_generate(results)
        end
      end
      
      # todo: might also sum by type
      summed_results = nil
      detailed_results_dir = File.join(File.dirname(__FILE__), "/run/#{@project_name}/#{scenario_name}/")
      get_all_datapoint_ids.each do |datapoint_id|
        file = get_detailed_results(datapoint_id)
        
        if save_datapoint_files
          FileUtils.mkdir_p(detailed_results_dir) if !File.exists?(detailed_results_dir) 
          result_path = File.join(detailed_results_dir, "#{datapoint_id}_timeseries.csv")
          File.open(result_path, "w") do |f|
            f.write(file)
          end
        end
        
        if summed_results.nil?
          summed_results = CSV.parse(file)
        else
          results = CSV.parse(file)
          results.each_index do |i|
            next if i < 1 # header
            
            summed_results[i].each_index do |j|
              summed_results[i][j] = summed_results[i][j].to_f + results[i][j].to_f
            end
          end
        end

      end
      
      summed_result_path = File.join(File.dirname(__FILE__), "/run/#{@project_name}/#{scenario_name}_timeseries.csv")
      File.open(summed_result_path, "w") do |f|
        summed_results.each do |row|
          f.write(CSV.generate_line(row))
        end
      end
        
    end
    
  end
  
end
