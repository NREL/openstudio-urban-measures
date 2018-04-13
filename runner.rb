######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

require 'rest-client'
require 'parallel'
require 'json'
require 'base64'
require 'csv'
require 'open3'
require 'rbconfig'

require_relative 'map_properties'

# Runner creates all datapoints in a project, it then downloads max_datapoints number of osws, then runs all downloaded osws
class Runner

  # include module containing configure_workflow
  include UrbanOptMapping

  def initialize(url, openstudio_exe, openstudio_measures, openstudio_files, project_id, user_name, user_pwd, max_datapoints, num_parallel, logger)
    @url = url
    @openstudio_exe = openstudio_exe
    @openstudio_measures = openstudio_measures
    @openstudio_files = openstudio_files
    @project_id = project_id
    @user_name = user_name
    @user_pwd = user_pwd
    @max_datapoints = max_datapoints
    @num_parallel = num_parallel
    @logger = logger
    
    @project = get_project
    @project_name = @project[:name] if @project
  end
  
  def update_measures
    measure_dir = File.join(File.dirname(__FILE__), "/measures")
    command = "'#{@openstudio_exe}' measure -t '#{measure_dir}'"
    @logger.info("Running command: '#{command}'")
    @logger.info("Current directory: '#{Dir.pwd}'")
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      # calling wait_thr.value blocks until command is complete
      if wait_thr.value.success?
        @logger.info("Command completed successfully")
      else
        @logger.error("Error running command: '#{command}'")
        @logger.error("#{stdout.read}")
        @logger.error("#{stderr.read}")
      end
    end
  end
  
  def clear_results(datapoint_ids = [])
    @logger.debug("clear_results, datapoint_ids = #{datapoint_ids}")
    
    if datapoint_ids.empty?
      datapoint_ids = get_all_datapoint_ids
    end
    
    datapoint_ids.each do |datapoint_id|
      datapoint = {}
      datapoint[:id] = datapoint_id
      datapoint[:status] = nil
      datapoint[:results] = nil
      
      osw_dir = File.join(File.dirname(__FILE__), "/run/#{@project_name}/datapoint_#{datapoint_id}")
      if File.exists?(osw_dir)
        @logger.debug("removing directory '#{osw_dir}'")
        FileUtils.rm_rf(osw_dir)
      end
      
      json_request = JSON.generate('project_id' => @project_id, 'datapoint' => datapoint)
      
      existing_datapoint = get_datapoint(datapoint_id)
      #@logger.debug("existing_datapoint = #{existing_datapoint}")
      
      if existing_datapoint[:datapoint_files]
        existing_datapoint[:datapoint_files].each do |file|
          filename = file[:file_name]
          @logger.debug("deleting file #{filename} for datapoint #{datapoint_id}")
          
          begin
            request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
            response = request["/api/delete_datapoint_file?datapoint_id=#{datapoint_id}&file_name=#{filename}"].get(content_type: :json, accept: :json)
          rescue => e
            @logger.error("Error in clear_results delete_datapoint_file: #{e.response}")
          end
        end
      end

      begin
        request = RestClient::Resource.new("#{@url}/api/datapoint", user: @user_name, password: @user_pwd)
        response = request.post(json_request, content_type: :json, accept: :json)    
      rescue RestClient::Exception  => e
        @logger.error("Error in clear_results: #{e.response}")
      rescue => e
        @logger.error("Error in clear_results: #{e}")
      end        
    end
  end
  
  def get_project()
    @logger.debug("get_project")
    
    result = nil
    begin
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/project?project_id=#{@project_id.to_s}"].get(content_type: :json, accept: :json)
      project = JSON.parse(response.body, :symbolize_names => true)
      result = project[:project]
    rescue => e
      @logger.error("Error in get_project: #{e.response}")
    end   

    # create project_files directory
    project_files_dir = File.join(File.dirname(__FILE__), "/run/#{result[:name]}/project_files")
    if !File.exists?(project_files_dir)
      FileUtils.mkdir_p(project_files_dir)
    end
    # download all project files
    @logger.debug("get_project_files")
    epw_names = []
    result[:project_files].each do |file|
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/retrieve_project_file?project_id=#{@project_id.to_s}&file_name=#{file[:file_name]}"].get(content_type: :json, accept: :json)
      temp = JSON.parse(response.body, :symbolize_names => true)
      file_data = temp[:file_data][:file]
      # base64 decode and write to run_dir/project_files (overwrite)
      raw_data = Base64.strict_decode64(file_data)
      file_path = File.join(File.dirname(__FILE__), "/run/#{result[:name]}/project_files/#{file[:file_name]}")
      File.open(file_path, 'wb' ) do |the_file|
        the_file.write raw_data
      end
      # hack: find name of epw file
      if file[:type] == 'epw'
        epw_names << file[:file_name]
      end
    end
    @logger.debug("epws found: #{epw_names}")
    # hack for weather files (epw, stat, and ddy must have exactly the same name)
    epw_names.each do |epw|
      epw = epw.gsub('.epw', '')
      last_part = epw.split('_').last 
      if !last_part.include?('TMY')
        @logger.debug("Fixing stat and ddy filename to match epw for: #{epw}")
        tmp = epw.split('_')
        basename = tmp[0..(tmp.size - 2)].join('_')

        # ensure same last part        
        result[:project_files].each do |file|
          if (file[:type] === 'ddy' || file[:type] === 'stat') && file[:file_name].include?(basename)
            # fix filename on disk (check that is hasn't been renamed already)

            if File.exist?(File.join(File.dirname(__FILE__), "/run/#{result[:name]}/project_files/#{file[:file_name]}"))
              File.rename(File.join(File.dirname(__FILE__), "/run/#{result[:name]}/project_files/#{file[:file_name]}"), File.join(File.dirname(__FILE__), "/run/#{result[:name]}/project_files/#{epw}.#{file[:type]}"))
            end
          end
        end
      end
    end
    
    return result
  end  
    
  def get_all_feature_ids(feature_type)
    @logger.debug("get_all_feature_ids, feature_type = #{feature_type}")
    
    result = []
    begin
      json_request = JSON.generate('types' => [feature_type], 'project_id' => @project_id)
      request = RestClient::Resource.new("#{@url}/api/export", user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)
      
      buildings = JSON.parse(response.body, :symbolize_names => true)
      buildings[:features].each do |building|
        result << building[:properties][:id]
      end
    rescue => e
      @logger.error("Error in get_all_feature_ids: #{e.response}")
    end   
    
    return result
  end
  
  def get_all_workflow_ids(feature_type)
    @logger.debug("get_all_workflow_ids, feature_type = #{feature_type}")
    
    result = []
    begin
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/workflows?project_id=#{@project_id.to_s}"].get(content_type: :json, accept: :json)
    
      workflows = JSON.parse(response.body, :symbolize_names => true)
      workflows.each do |workflow|
        if feature_type != workflow[:feature_type]
          @logger.debug("skipping workflow with feature_type '#{workflow[:feature_type]}', requested feature_type '#{feature_type}'")
          next
        end
      end
    rescue => e
      @logger.error("Error in get_all_workflow_ids: #{e.response}")
    end   
    
    @logger.debug("get_all_workflow_ids = #{result.join(',')}")
    return result
  end
  
  def get_all_scenario_ids()
    @logger.debug("get_all_scenario_ids")
    
    result = []
    begin
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/scenarios?project_id=#{@project_id.to_s}"].get(content_type: :json, accept: :json)
    
      scenarios = JSON.parse(response.body, :symbolize_names => true)
      scenarios.each do |scenario|
        result << scenario[:id]
      end
    rescue => e
      @logger.error("Error in get_all_scenario_ids: #{e.response}")
    end   
  
    @logger.debug("get_all_scenario_ids = #{result.join(',')}")
    return result
  end
  
  # DEPRECATED
  def get_all_datapoint_ids()
    @logger.debug("get_all_datapoint_ids...this method is DEPRECATED")
    
    result = []
    begin
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/datapoints?project_id=#{@project_id.to_s}"].get(content_type: :json, accept: :json)
    
      datapoints = JSON.parse(response.body, :symbolize_names => true)
      
      # sort building datapoints before district system ones
      feature_types = ['Building', 'District System']
      datapoints.sort!{|a,b| feature_types.index(a[:feature_type]) <=> feature_types.index(b[:feature_type])}
      
      # make an array of datapoint IDs only
      result = datapoints.map{|x| x[:id]}

    rescue => e
      @logger.error("Error in get_all_datapoint_ids: #{e.response}")
    end   
    
    @logger.debug("get_all_datapoint_ids = #{result.join(',')}")
    return result
  end

  def get_datapoint_ids_by_type(datapoint_ids = [])
    @logger.debug("get_datapoint_ids_by_type")
    
    result = []
    begin
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/datapoints?project_id=#{@project_id.to_s}"].get(content_type: :json, accept: :json)

      datapoints = JSON.parse(response.body, :symbolize_names => true)

      if datapoint_ids.length > 0
        # select datapoints down to subset
        datapoints = datapoints.select{ |dp| datapoint_ids.include? dp[:id] }
      end

      # separate buildings, district systems, and transformers
      new_dps = {}
      new_dps[:buildings] = datapoints.select { |dp| dp[:feature_type] == 'Building'}
      new_dps[:district_systems] = datapoints.select { |dp| dp[:feature_type] == 'District System' && dp[:district_system_type] && dp[:district_system_type] != 'Transformer'}     
      new_dps[:transformers] = datapoints.select { |dp| dp[:feature_type] == 'District System' && dp[:district_system_type] && dp[:district_system_type] == 'Transformer'}

      result = {}
      new_dps.each do |key, dpArr|
        result[key] = dpArr.map{|x| x[:id]}
      end

    rescue => e
      @logger.error("Error in get_datapoint_ids_by_type: #{e.response}")
    end   
    
    @logger.debug("get_datapoint_ids_by_type = #{result}")
    return result
  end
  
  def get_or_create_datapoint(feature_id, option_set_id, scenario_id)
    @logger.debug("get_or_create_datapoint, feature_id = #{feature_id}, option_set_id = #{option_set_id}, scenario_id = #{scenario_id}")
    
    result = nil
    begin
      json_request = JSON.generate('feature_id' => feature_id, 'option_set_id' => option_set_id, 'scenario_id' => scenario_id, 'project_id' => @project_id)
      request = RestClient::Resource.new("#{@url}/api/retrieve_datapoint", user: @user_name, password: @user_pwd)
      response = request.post(json_request, content_type: :json, accept: :json)
      datapoint = JSON.parse(response.body, :symbolize_names => true)
      result = datapoint[:datapoint]
    rescue => e
      @logger.error("Error in get_all_datapoint_ids: #{e.response}")
    end   
    
    return result
  end

   def get_datapoint(datapoint_id)
    @logger.debug("get_datapoint, datapoint_id = #{datapoint_id}")
    
    result = nil
    begin    
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/retrieve_datapoint?project_id=#{@project_id}&datapoint_id=#{datapoint_id}"].get(content_type: :json, accept: :json)
      datapoint = JSON.parse(response.body, :symbolize_names => true)
      result = datapoint[:datapoint]
    rescue => e
      @logger.error("Error in get_datapoint: #{e.response}")
    end   
    
    return result
  end
  
  def get_option_set(option_set_id)
    @logger.debug("get_option_set, option_set_id = #{option_set_id}")
    
    result = nil
    begin    
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/retrieve_option_set?project_id=#{@project_id}&option_set_id=#{option_set_id}"].get(content_type: :json, accept: :json)
      datapoint = JSON.parse(response.body, :symbolize_names => true)
      result = datapoint[:option_set]
    rescue => e
      @logger.error("Error in get_option_set: #{e.response}")
    end
      
    return result
  end
  
  def get_feature(feature_id)
    @logger.debug("feature_id, feature_id = #{feature_id}")
    
    result = nil
    begin        
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/feature?project_id=#{@project_id}&feature_id=#{feature_id}"].get(content_type: :json, accept: :json)
      feature = JSON.parse(response.body, :symbolize_names => true)
      result = feature
    rescue => e
      @logger.error("Error in get_feature: #{e.response}")
    end
      
    return result
  end
  
  def get_scenario(scenario_id)
    @logger.debug("get_scenario, scenario_id = #{scenario_id}")

    result = nil
    begin
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/retrieve_scenario?project_id=#{@project_id}&scenario_id=#{scenario_id}"].get(content_type: :json, accept: :json)
      scenario = JSON.parse(response.body, :symbolize_names => true)
      result = scenario[:scenario]
    rescue => e
      @logger.error("Error in get_scenario: #{e.response}")
    end

    return result
  end
  
  def get_results(scenario_id)
    @logger.debug("get_results, scenario_id = #{scenario_id}")
    
    results = nil
    begin
      request = RestClient::Resource.new("#{@url}/api/scenario_features.json?project_id=#{@project_id}&scenario_id=#{scenario_id}", user: @user_name, password: @user_pwd)
      response = request.get(content_type: :json, accept: :json)
      results = JSON.parse(response.body, :symbolize_names => true)
    rescue => e
      @logger.error("Error in get_results: #{e.response}")
    end
    
    return results
  end
  
  def get_detailed_results(datapoint_id)
    @logger.debug("get_detailed_results, datapoint_id = #{datapoint_id}")
    
    datapoint = nil
    begin
      request = RestClient::Resource.new("#{@url}", user: @user_name, password: @user_pwd)
      response = request["/api/retrieve_datapoint?project_id=#{@project_id}&datapoint_id=#{datapoint_id}"].get(content_type: :json, accept: :json)
      datapoint = JSON.parse(response.body, :symbolize_names => true)[:datapoint]
    rescue => e
      @logger.error("Error in get_detailed_results: #{e.response}")
      return nil
    end
    
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
  def create_osws(datapoint_ids = [])
    @logger.debug("create_osws")
    result = {}
    
    # datapoint IDs may be passed in (from run_datapoints)
    # connect to database, get list of all datapoint ids
    all_datapoint_ids = get_datapoint_ids_by_type(datapoint_ids)
    
    # loop over all combinations
    num_datapoints = 0
	
	all_datapoint_ids.each do |key, dpArr|
	
      result[key] = []
	 
	  n_remaining = [0,@max_datapoints - num_datapoints].max
	  n = [dpArr.size,n_remaining].min
	  dpArr = dpArr[0,n]
	  num_datapoints += n

      #dpArr.each do |datapoint_id|
	  Parallel.each(dpArr, in_threads: [@max_datapoints,@num_parallel].min) do |datapoint_id|
			
		datapoint = get_datapoint(datapoint_id) 
		
		# see if datapoint needs to be run
		if datapoint[:status] 
		  if datapoint[:status] == "Started"
			@logger.debug("Skipping Started Datapoint")
			next
		  elsif datapoint[:status] == "Complete"
			@logger.debug("Skipping Complete Datapoint")
			next
		  elsif datapoint[:status] == "Failed"
			#@logger.debug("Skipping Failed Datapoint")
			#next
		  end
		end
		@logger.debug("Saving Datapoint #{datapoint}")
	  
		result[key] << create_osw(datapoint_id)

      end
    end
    
    return result
  end

  def create_osw(datapoint_id)
    @logger.debug("create_osw, datapoint_id = #{datapoint_id}")
    
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
    
    if project[:properties].nil?
      project[:properties] = {}
    end
    
    workflow.delete(:datapoints)
    
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
      
      # DLM: in case the arguments were removed 
      if step[:measure_dir_name] == "urban_geometry_creation"
        step[:arguments][:city_db_url] = @url
        step[:arguments][:project_id] = @project_id
        step[:arguments][:feature_id] = feature_id
      elsif step[:measure_dir_name] == "datapoint_reports"
        step[:arguments][:city_db_url] = @url
        step[:arguments][:project_id] = @project_id
        step[:arguments][:datapoint_id] = datapoint_id
      elsif step[:measure_dir_name] == "import_district_system_loads"
        step[:arguments][:city_db_url] = @url
        step[:arguments][:project_id] = @project_id
        step[:arguments][:scenario_id] = scenario_id
        step[:arguments][:feature_id] = feature_id
      end
    end

    # now do mapping
    workflow = configure_workflow(workflow, feature, project)
    
    workflow[:file_paths] = @openstudio_files
    workflow[:measure_paths] = @openstudio_measures
    workflow[:run_options] = {output_adapter:{custom_file_name:File.join(File.dirname(__FILE__), "./adapters/output_adapter.rb"), class_name:"CityDB",options:{url:@url,datapoint_id:datapoint_id,project_id:@project_id}}}

    # save workflow
    osw_dir = File.join(File.dirname(__FILE__), "/run/#{@project_name}/datapoint_#{datapoint_id}")
    FileUtils.rm_rf(osw_dir)
    FileUtils.mkdir_p(osw_dir)
 
    osw_path = "#{osw_dir}/in.osw"
    
    FileUtils.rm_rf(osw_path) if File.exists?(osw_path)

    File.open(osw_path, 'w') do |file|
      file << JSON.pretty_generate(workflow)
    end
            
    return osw_dir
  end
  
  def run_osws(dirs)
    @logger.debug("run_osws, dirs = #{dirs}")

    dirs.each do |key, dirArr|
      # do buildings first, then district systems, then transformers
      Parallel.each(dirArr, in_threads: [@max_datapoints,@num_parallel].min) do |osw_dir|
        
        md = /datapoint_(.*)/.match(osw_dir)
        next if !md
        
        osw_path = File.join(osw_dir, "in.osw")
        
        datapoint_id = md[1].gsub('/','')
        
        # to run with the CLI
        #command = "'#{@openstudio_exe}' run -w '#{osw_path}'"
        
        # to run with current ruby
        ruby_exe = File.join( RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'] )
        openstudio_rb_dir = File.join(File.dirname(@openstudio_exe), "../Ruby/")
        run_rb = File.join(File.dirname(__FILE__), "run.rb")
        command = "bundle exec '#{ruby_exe}' '#{run_rb}' '#{openstudio_rb_dir}' '#{osw_path}'"
        #command = "'#{ruby_exe}' '#{ruby_exe.gsub('ruby.exe', 'bundle')}' '#{ruby_exe}' '#{run_rb}' '#{openstudio_rb_dir}' '#{osw_path}'"
        #command = "'#{ruby_exe}' '#{run_rb}' '#{openstudio_rb_dir}' '#{osw_path}'"
        
        @logger.info("Running command: '#{command}'")
        @logger.info("Current directory: '#{Dir.pwd}'")
        @logger.info("ENV['GEM_HOME']: '#{ENV['GEM_HOME']}'")
        @logger.info("ENV['GEM_PATH']: '#{ENV['GEM_PATH']}'")
        
        new_env = {}
        new_env["URBANOPT_USERNAME"] = @user_name
        new_env["URBANOPT_PASSWORD"] = @user_pwd
        
        # blank out bundler and gem path modifications, will be re-setup by new call
        new_env["BUNDLER_ORIG_MANPATH"] = nil
        new_env["GEM_PATH"] = nil
        new_env["GEM_HOME"] = nil
        new_env["BUNDLER_ORIG_PATH"] = nil
        new_env["BUNDLER_VERSION"] = nil
        new_env["BUNDLE_BIN_PATH"] = nil
        new_env["BUNDLE_GEMFILE"] = nil
        new_env["RUBYLIB"] = nil
        new_env["RUBYOPT"] = nil
        
        # ok to put user name and password in environment variables?
        stdout_str, stderr_str, status = Open3.capture3(new_env, command)
        if status.success?
          @logger.info("'#{osw_path}' completed successfully")
        else
          @logger.error("Error running command: '#{command}'")
          #@logger.error(stdout_str)
          #@logger.error(stderr_str)
        end
        
        #Open3.popen3(new_env, command) do |stdin, stdout, stderr, wait_thr|
        #  # calling wait_thr.value blocks until command is complete
        #  if wait_thr.value.success?
        #    @logger.info("'#{osw_path}' completed successfully")
        #  else
        #    @logger.error("Error running command: '#{command}'")
        #    @logger.error("#{stdout.read}")
        #    @logger.error("#{stderr.read}")
        #  end
        #end
      end
    end
  end
  
  def save_results(save_datapoint_files = false)
    @logger.debug("save_results")
    all_scenario_ids = get_all_scenario_ids()
    
    timesteps_per_hour = nil
    begin_month = nil
    begin_day_of_month = nil
    end_month = nil
    end_day_of_month = nil
    begin_year = nil
    duration_days = nil
    duration_hours = nil
    
    all_scenario_results = []
    all_scenario_ids.each do |scenario_id|
      scenario = get_scenario(scenario_id)
      scenario_name = scenario[:name]
      
      scenario_results = get_results(scenario_id)
      scenario_results[:name] = scenario_name
      
      # todo: might also sum by type
      summed_results = nil
      missing_results = []
      detailed_results_dir = File.join(File.dirname(__FILE__), "/run/#{@project_name}/#{scenario_name}/")
      scenario[:datapoints].each do |datapoint|
        datapoint_id = datapoint[:id]
        file = get_detailed_results(datapoint_id)

        # grab timestep and duration_hours
        if timesteps_per_hour.nil?
          datapoint = get_datapoint(datapoint_id)
          puts datapoint

          if (datapoint.key?(:results))
            timesteps_per_hour = datapoint[:results][:timesteps_per_hour]
            begin_month = datapoint[:results][:begin_month]
            begin_day_of_month = datapoint[:results][:begin_day_of_month]
            end_month = datapoint[:results][:end_month]
            end_day_of_month = datapoint[:results][:end_day_of_month]
            begin_year = datapoint[:results][:begin_year]
          
            end_year = begin_year
            if end_month < begin_month  
              end_year = begin_year + 1
            elsif end_month == begin_month
              if end_day_of_month < begin_day_of_month
                end_year = begin_year + 1
              end
            end
            
            d1 = Date.new(begin_year, begin_month, begin_day_of_month)
            d2 = Date.new(end_year, end_month, end_day_of_month, end_year)
            duration_days = (d2-d1).to_i + 1
            duration_hours = 24*duration_days
          else
            # set these to 0 for failed datapoints
            timesteps_per_hour = 0;
            duration_hours = 0;
          end
        end         
        
        if save_datapoint_files
          FileUtils.mkdir_p(detailed_results_dir) if !File.exists?(detailed_results_dir) 
          result_path = File.join(detailed_results_dir, "#{datapoint_id}_timeseries.csv")
          File.open(result_path, "w") do |f|
            f.write(file)
          end
        end
        
        if file.nil?
          missing_results << datapoint_id
        elsif summed_results.nil?
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
      scenario_results[:missing_results] = missing_results
      
      # write out combined CSV
      summed_result_path = File.join(File.dirname(__FILE__), "/run/#{@project_name}/#{scenario_name}_timeseries.csv")
      if summed_results
        File.open(summed_result_path, "w") do |f|
          summed_results.each do |row|
            f.write(CSV.generate_line(row))
          end
        end
      end
      
      # write out any missing results
      missing_results_path = File.join(File.dirname(__FILE__), "/run/#{@project_name}/#{scenario_name}_missing_results.txt")
      if missing_results.size > 0
        File.open(missing_results_path, "w") do |f|
          missing_results.each do |missing_result|
            f << "Datapoint #{missing_result} does not have timeseries results"
          end
        end
      else
        if File.exists?(missing_results_path)
          FileUtils.rm(missing_results_path)
        end
      end

      # aggregate timeseries into hourly, daily, monthly, and annual values
      i = 0
      num_rows = duration_hours*timesteps_per_hour
      headers = []
      timestep_values = {}
      hourly_values = {}
      daily_values = {}
      monthly_values = {}
      annual_values = {}

      if File.exists?(summed_result_path)
        CSV.foreach(summed_result_path) do |row|
          if i == 0
            # header row
            headers = row
            headers.each do |header|
              annual_values[header] = 0
              timestep_values[header] = []
              daily_values[header] = []
            end
          elsif i <= num_rows
            headers.each_index do |j|
              annual_values[headers[j]] += row[j].to_f
              timestep_values[headers[j]] << row[j].to_f 
            end
          end
          i += 1
        end
      end

      headers.each_index do |j|

        all_values = timestep_values[headers[j]]
        
        raise "Wrong size #{all_values.size} != #{num_rows}" if all_values.size != num_rows
        
        # hourly sums
        
        i = 1
        hour_sum = 0
        hourly_sums = []
        all_values.each do |v|
          hour_sum += v
          if i == timesteps_per_hour
            hourly_sums << hour_sum
            i = 1
            hour_sum = 0
          else
            i += 1
          end
        end
        
        raise "Wrong size #{hourly_sums.size} != #{duration_hours}" if hourly_sums.size != duration_hours
        
        hourly_values[headers[j]] = hourly_sums
        
        # daily sums
        
        i = 1
        day_sum = 0
        daily_sums = []
        all_values.each do |v|
          day_sum += v
          if i == 24*timesteps_per_hour
            daily_sums << day_sum
            i = 1
            day_sum = 0
          else
            i += 1
          end
        end
        
        raise "Wrong size #{daily_sums.size} != #{duration_days}" if daily_sums.size != duration_days
        
        daily_values[headers[j]] = daily_sums
        
        monthly_sums = []
        if begin_month == 1 && begin_day_of_month == 1 && end_month == 12 && end_day_of_month == 31
          # horrendous monthly sums
          
          days_per_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
          k = 0
          monthly_sum = 0
          days_per_month.each do |days|
            (1..days).each do |day|
              monthly_sum += daily_sums[k]
              k += 1
            end
            
            monthly_sums << monthly_sum
            monthly_sum = 0
          end
        
          raise "Wrong size #{k} != 365" if k != 365
        end
        
        monthly_values[headers[j]] = monthly_sums
      end

      #scenario_results[:timestep_values] = timestep_values
      #scenario_results[:hourly_values] = hourly_values
      #scenario_results[:daily_values] = daily_values
      scenario_results[:monthly_values] = monthly_values
      scenario_results[:annual_values] = annual_values
      
      results_path = File.join(File.dirname(__FILE__), "/run/#{@project_name}/#{scenario_name}.geojson")
      results_dir = File.dirname(results_path)
      if !File.exists?(results_dir)
        FileUtils.mkdir_p(results_dir)
      end
      
      File.open(results_path, 'w') do |file|
        file << JSON.pretty_generate(scenario_results)
      end
      
      all_scenario_results << scenario_results

    end
    
    results_path = File.join(File.dirname(__FILE__), "/run/#{@project_name}/scenarioData.js")
    File.open(results_path, 'w') do |file|
      file << "var scenarioData = #{JSON.pretty_generate(all_scenario_results)};"
    end
    
    # copy results htmls
    html_in_path = "#{File.dirname(__FILE__)}/reports/scenario_comparison.html"
    html_out_path = File.join(File.dirname(__FILE__), "/run/#{@project_name}/scenario_comparison.html")
    FileUtils.cp(html_in_path, html_out_path)
  end
  
end
