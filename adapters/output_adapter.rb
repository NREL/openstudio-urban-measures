######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

require 'openstudio'
require 'openstudio-workflow'
require 'openstudio/workflow/adapters/output_adapter'

require 'net/http'
require 'openssl'
require 'uri'
require 'base64'

class CityDB < OpenStudio::Workflow::OutputAdapters
  def initialize(options = {})
    raise 'The required :output_directory option was not passed to the local output adapter' unless options[:output_directory]
    raise 'The required :url option was not passed to the local output adapter' unless options[:url]
    raise 'The required :datapoint_id option was not passed to the local output adapter' unless options[:datapoint_id]
    raise 'The required :project_id option was not passed to the local output adapter' unless options[:project_id]
    uri = URI.parse(options[:url])

    @url = uri.host
    @port = uri.port
    @is_https = (uri.scheme == 'https')

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
    http.read_timeout = 1000
    if @is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Post.new('/api/datapoint.json')
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.body = JSON.generate(params)
    request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])

    response = http.request(request)
    if response.code != '200' && response.code != '201' # success
      puts "Bad response #{response.code}"
      File.open("#{@options[:output_directory]}/datapoint_error.html", 'w') { |f| f.puts response.body }
      return false
    end

    return true
  end

  def send_file(path)
    if !File.exist?(path)
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
    params[:project_id] = @options[:project_id]
    params[:file_data] = file_data

    puts "sending file '#{path}'"
    visible_params = Marshal.load(Marshal.dump(params))
    visible_params[:file_data].delete(:file)
    puts visible_params

    http = Net::HTTP.new(@url, @port)
    http.read_timeout = 1000
    if @is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Post.new('/api/datapoint_file.json')
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.body = JSON.generate(params)
    request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])

    response = http.request(request)
    if response.code != '200' && response.code != '201' # success
      puts "Bad response #{response.code}"
      File.open("#{@options[:output_directory]}/datapoint_file_error.html", 'w') { |f| f.puts response.body }
      return false
    end

    return true
  end

  # Write that the process has started
  def communicate_started
    File.open("#{@options[:output_directory]}/started.job", 'w') { |f| f << "Started Workflow #{::Time.now} #{@options}" }
    raise 'Missing required options' unless @options[:url] && @options[:datapoint_id] && @options[:project_id]
    send_status('Started')
  end

  # Write that the process has completed
  def communicate_complete
    File.open("#{@options[:output_directory]}/finished.job", 'w') { |f| f << "Finished Workflow #{::Time.now} #{@options}" }
    raise 'Missing required options' unless @options[:url] && @options[:datapoint_id] && @options[:project_id]
    send_status('Complete')
    send_file("#{@options[:output_directory]}/run.log")
    Dir.glob("#{@options[:output_directory]}/../reports/*").each do |f|
      next if File.basename(f) == 'view_model_report.json'

      send_file(f)
    end
  end

  # Write that the process has failed
  def communicate_failure
    File.open("#{@options[:output_directory]}/failed.job", 'w') { |f| f << "Failed Workflow #{::Time.now} #{@options}" }
    raise 'Missing required options' unless @options[:url] && @options[:datapoint_id] && @options[:project_id]
    send_status('Failed')
    send_file("#{@options[:output_directory]}/run.log")
    Dir.glob("#{@options[:output_directory]}/../reports/*").each { |f| send_file(f) }
  end

  # Do nothing on a state transition
  def communicate_transition(_ = nil, _ = nil); end

  # Do nothing on E+ std out
  def communicate_energyplus_stdout(_ = nil, _ = nil); end

  # Do nothing on Measure result
  def communicate_measure_result(_ = nil, _ = nil); end

  # Write the measure attributes to the filesystem
  def communicate_measure_attributes(measure_attributes, _ = nil)
    # File.open("#{@options[:output_directory]}/measure_attributes.json", 'w') do |f|
    #  f << JSON.pretty_generate(measure_attributes)
    # end
  end

  # Write the objective function results to the filesystem
  def communicate_objective_function(objectives, _ = nil)
    # obj_fun_file = "#{@options[:output_directory]}/objectives.json"
    # FileUtils.rm_f(obj_fun_file) if File.exist?(obj_fun_file)
    # File.open(obj_fun_file, 'w') { |f| f << JSON.pretty_generate(objectives) }
  end

  # Write the results of the workflow to the filesystem
  def communicate_results(directory, results)
    zip_results(directory)

    # if results.is_a? Hash
    #  File.open("#{@options[:output_directory]}/data_point_out.json", 'w') { |f| f << JSON.pretty_generate(results) }
    # else
    #  puts "Unknown datapoint result type. Please handle #{results.class}"
    # end
  end
end
