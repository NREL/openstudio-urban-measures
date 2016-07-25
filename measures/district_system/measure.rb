# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'json'
require 'net/http'

# start the measure
class DistrictSystem < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "District System"
  end

  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # url of the city database
    city_db_url = OpenStudio::Ruleset::OSArgument.makeStringArgument("city_db_url", true)
    city_db_url.setDisplayName("City Database Url")
    city_db_url.setDescription("Url of the City Database")
	  #city_db_url.setDefaultValue("http://localhost:3000")
    city_db_url.setDefaultValue("http://insight4.hpc.nrel.gov:8081/")
    args << city_db_url
    
    # project id
    project_id = OpenStudio::Ruleset::OSArgument.makeStringArgument("project_id", true)
    project_id.setDisplayName("Project ID")
    project_id.setDescription("Project ID.")
    args << project_id
    
    # building workflow id
    # todo: DLM, this should be scenario ID
    building_workflow_id = OpenStudio::Ruleset::OSArgument.makeStringArgument("building_workflow_id", true)
    building_workflow_id.setDisplayName("Building Workflow ID")
    building_workflow_id.setDescription("Building Workflow ID.")
    args << building_workflow_id

    return args
  end
  
  # get the project from the database
  def get_datapoint_ids(project_id, building_workflow_id)
  
    http = Net::HTTP.new(@city_db_url, @port)
    request = Net::HTTP::Get.new("/datapoints.json")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    
    # DLM: todo, get these from environment variables or as measure inputs?
    request.basic_auth("test@nrel.gov", "testing123")
  
    response = http.request(request)
    if  response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      return {}
    end
    
    datapoints = JSON.parse(response.body, :symbolize_names => true)
    
    result = []
    datapoints.each do |datapoint|
      if datapoint[:project_id] == project_id
        if datapoint[:workflow_id] == building_workflow_id
          result << datapoint[:id]
        end
      end
    end
    
    return result
  end
  
  def download_datapoint(datapoint_id)
    http = Net::HTTP.new(@city_db_url, @port)
    request = Net::HTTP::Get.new("/datapoints/#{datapoint_id}.json")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    
    # DLM: todo, get these from environment variables or as measure inputs?
    request.basic_auth("test@nrel.gov", "testing123")
  
    response = http.request(request)
    if  response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      return {}
    end
    
    datapoint = JSON.parse(response.body, :symbolize_names => true)[:datapoint]
    datapoint_files = datapoint[:datapoint_files]
    if datapoint_files
      datapoint_files.each do |datapoint_file|
        if /datapoint_reports_report\.csv/.match( datapoint_file[:file_name] )
          file_id = datapoint_file[:_id][:$oid]
          puts "http://localhost:3000/datapoints/#{datapoint_id}/download_file?file_id=#{file_id}"
        end
      end
    end
    
    #http://localhost:3000/datapoints/57966325c44c8d3924000031/download_file?file_id=579683a7c44c8d3924000046
  end
  
  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    # assign the user inputs to variables
    city_db_url = runner.getStringArgumentValue("city_db_url", user_arguments)
    project_id = runner.getStringArgumentValue("project_id", user_arguments)
    building_workflow_id = runner.getStringArgumentValue("building_workflow_id", user_arguments)
    
    @runner = runner
    
    @port = 80
    if md = /http:\/\/(.*):(\d+)/.match(city_db_url)
      @city_db_url = md[1]
      @port = md[2]
    elsif /http:\/\/([^:\/]*)/.match(city_db_url)
      @city_db_url = md[1]
    end

    
    datapoint_ids = get_datapoint_ids(project_id, building_workflow_id)
    
    datapoint_files = []
    datapoint_ids.each do |datapoint_id|
      datapoint_files << download_datapoint(datapoint_id)
    end
    
    return true

  end
  
end

# register the measure to be used by the application
DistrictSystem.new.registerWithApplication
