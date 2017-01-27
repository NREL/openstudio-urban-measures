require 'openstudio'
require 'openstudio-workflow'
require 'openstudio/workflow/adapters/output_adapter'

require 'base64'

class CityDB < OpenStudio::Workflow::OutputAdapters
  def initialize(options = {})

    fail 'The required :output_directory option was not passed to the local output adapter' unless options[:output_directory]
    fail 'The required :url option was not passed to the local output adapter' unless options[:url]
    fail 'The required :datapoint_id option was not passed to the local output adapter' unless options[:datapoint_id]
    fail 'The required :project_id option was not passed to the local output adapter' unless options[:project_id]
    @url = options[:url]
    
    @port = 80
    if md = /http:\/\/(.*):(\d+)/.match(@url)
      @url = md[1]
      @port = md[2]
    elsif /http:\/\/([^:\/]*)/.match(@url)
      @url = md[1]
    end
    
    @user_name = 'test@nrel.gov'
    @user_pwd = 'testing123'
    super
  end
  
  def send_status(status)

    datapoint = {}
    datapoint[:id] = @options[:datapoint_id]
    datapoint[:status] = status

    params = {}
    params[:project_id] = @options[:project_id]
    params[:datapoint] = datapoint
    
    http = Net::HTTP.new(@url, @port)
    request = Net::HTTP::Post.new("/api/datapoint.json")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.body = JSON.generate(params)
    # DLM: todo, get these from environment variables or as measure inputs?
    request.basic_auth(@user_name, @user_pwd)
  
    response = http.request(request)
    if response.code != '200' # success
      puts "Bad response #{response.code}"
      File.open("#{@options[:output_directory]}/error.html", 'w') {|f| f.puts response.body}
      return false
    end
    
    return true
  end
  
  def send_file(path)
    if !File.exists?(path)
      puts "send_file cannot open file '#{path}'"
      return false
    end

    the_file = ''
    File.open(path, 'rb') do |file|
      the_file = Base64.strict_encode64(file.read)
    end
    
    if the_file.empty?
      the_file = Base64.strict_encode64("\n")
    end

    file_data = {}
    file_data[:file_name] = File.basename(path)
    file_data[:file] = the_file

    params = {}
    params[:datapoint_id] = @options[:datapoint_id]
    params[:file_data] = file_data
    
    puts "sending file '#{path}'"
    visible_params = Marshal.load(Marshal.dump(params))
    visible_params[:file_data].delete(:file)
    puts visible_params
    
    http = Net::HTTP.new(@url, @port)
    request = Net::HTTP::Post.new("/api/datapoint_file")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.body = JSON.generate(params)
    # DLM: todo, get these from environment variables or as measure inputs?
    request.basic_auth(@user_name, @user_pwd)
  
    response = http.request(request)
    if response.code != '200' # success
      puts "Bad response #{response.code}"
      File.open("#{@options[:output_directory]}/error.html", 'w') {|f| f.puts response.body}
      return false
    end
    
    return true
  end

  # Write that the process has started
  def communicate_started
    File.open("#{@options[:output_directory]}/started.job", 'w') { |f| f << "Started Workflow #{::Time.now} #{@options}" }
    fail 'Missing required options' unless @options[:url] && @options[:datapoint_id] && @options[:project_id]
    send_status("Started")
  end

  # Write that the process has completed
  def communicate_complete
    File.open("#{@options[:output_directory]}/finished.job", 'w') { |f| f << "Finished Workflow #{::Time.now} #{@options}" }
    fail 'Missing required options' unless @options[:url] && @options[:datapoint_id] && @options[:project_id]
    send_status("Complete")
    send_file("#{@options[:output_directory]}/run.log")
    Dir.glob("#{@options[:output_directory]}/../reports/*").each { |f| send_file(f) }
  end

  # Write that the process has failed
  def communicate_failure
    File.open("#{@options[:output_directory]}/failed.job", 'w') { |f| f << "Failed Workflow #{::Time.now} #{@options}" }
    fail 'Missing required options' unless @options[:url] && @options[:datapoint_id] && @options[:project_id]
    send_status("Failed")
    send_file("#{@options[:output_directory]}/run.log")
    Dir.glob("#{@options[:output_directory]}/../reports/*").each { |f| send_file(f) }
  end

  # Do nothing on a state transition
  def communicate_transition(_=nil, _=nil) 
  end
  
  # Do nothing on E+ std out
  def communicate_energyplus_stdout(_=nil, _=nil) 
  end

  # Write the measure attributes to the filesystem
  def communicate_measure_attributes(measure_attributes, _=nil)
    #File.open("#{@options[:output_directory]}/measure_attributes.json", 'w') do |f|
    #  f << JSON.pretty_generate(measure_attributes)
    #end
  end

  # Write the objective function results to the filesystem
  def communicate_objective_function(objectives, _=nil)
    #obj_fun_file = "#{@options[:output_directory]}/objectives.json"
    #FileUtils.rm_f(obj_fun_file) if File.exist?(obj_fun_file)
    #File.open(obj_fun_file, 'w') { |f| f << JSON.pretty_generate(objectives) }
  end

  # Write the results of the workflow to the filesystem
  def communicate_results(directory, results)
    zip_results(directory)

    #if results.is_a? Hash
    #  File.open("#{@options[:output_directory]}/data_point_out.json", 'w') { |f| f << JSON.pretty_generate(results) }
    #else
    #  puts "Unknown datapoint result type. Please handle #{results.class}"
    #end
  end
end
