# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'json'
require 'net/http'
require 'base64'
require 'csv'

# start the measure
class ImportDistrictSystemLoads < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Import District System Loads"
  end

  # human readable description
  def description
    return "Imports District System Loads as Schedules"
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
      @result = false
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
      @result = false
    end

    datapoint = JSON.parse(response.body, :symbolize_names => true)[:datapoint]
    datapoint_files = datapoint[:datapoint_files]
    if datapoint_files
      datapoint_files.each do |datapoint_file|
        if /datapoint_reports_report\.csv/.match( datapoint_file[:file_name] )
          file_name = datapoint_file[:file_name]
          file_id = datapoint_file[:_id][:$oid]

          http = Net::HTTP.new(@city_db_url, @port)
          request = Net::HTTP::Get.new("/api/retrieve_datapoint_file.json?datapoint_id=#{datapoint_id}&file_name=#{file_name}")
          "/api/retrieve_datapoint_file.json?datapoint_id=#{datapoint_id}&file_name=#{file_name}"
          
          # DLM: todo, get these from environment variables or as measure inputs?
          request.basic_auth("test@nrel.gov", "testing123")
       
          response = http.request(request)
          if  response.code != '200' # success
            @runner.registerError("Bad response #{response.code}")
            @runner.registerError(response.body)
            @result = false
          end
          
          file_data = JSON.parse(response.body, :symbolize_names => true)[:file_data]
          file = Base64.strict_decode64(file_data[:file])

          filename = "#{datapoint_id}_timeseries.csv"
          File.open(filename, "w") do |f|
            f.write(file)
          end
          return filename
        end
      end
    end
    
    return nil
  end
  
  def makeSchedule(start_date, time_step, values, model, basename, ts)
  
    maximum = OpenStudio::maximum(values)
    minimum = OpenStudio::minimum(values)
    if ts[:normalize]
      n = values.size
      (0...n).each do |i|
        if maximum == 0
          values[i] = 0
        else
          values[i] = values[i]/maximum
        end
      end
    end
  
    name = "#{basename} #{ts[:name]}"
    if maximum == minimum
      schedule = OpenStudio::Model::ScheduleConstant.new(model)
      schedule.setValue(maximum)
    else
      timeseries = OpenStudio::TimeSeries.new(start_date, time_step, values, ts[:units])
      schedule = OpenStudio::Model::ScheduleInterval.fromTimeSeries(timeseries, model)
      if schedule.empty?
        @runner.registerError("Could not create schedule '#{name}'")
        @result = false
        return nil
      end
      schedule = schedule.get
    end
  
    schedule.setName(name)
    schedule.setComment("Maximum = #{maximum}")
    return schedule
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
    @result = true
    
    @port = 80
    if md = /http:\/\/(.*):(\d+)/.match(city_db_url)
      @city_db_url = md[1]
      @port = md[2]
    elsif /http:\/\/([^:\/]*)/.match(city_db_url)
      @city_db_url = md[1]
    end

    # DLM: this should be all datapoints for buildings on this system in this scenario
    datapoint_ids = get_datapoint_ids(project_id, building_workflow_id)
    
    datapoint_files = []
    datapoint_ids.each do |datapoint_id|
      datapoint_file = download_datapoint(datapoint_id)
      if datapoint_file
        datapoint_files << datapoint_file
      end
    end
    
    # 15 minute timesteps
    num_rows = 8760*4
    start_date = model.getYearDescription.makeDate(1,1)
    time_step = OpenStudio::Time.new(0,0,15,0)
    
    electric_schedules = []
    gas_schedules = []
    district_cooling_schedules = []
    district_heating_schedules = []
    
    datapoint_files.each do |file|
    
      puts "Reading #{file}"
      
      basename = File.basename(file, '.csv').gsub('_timeseries', '')
      
      i = 0
      headers = []
      values = {}
      CSV.foreach(file) do |row|
        if i == 0
          # header row
          headers = row
          headers.each do |header|
            values[header] = OpenStudio::Vector.new(num_rows)
          end
        elsif i <= num_rows
          headers.each_index do |j|
            values[headers[j]][i-1] = row[j].to_f
          end
        end
        i += 1
      end
  
      timeseries = [{name: "District Cooling Chilled Water Rate", units: "W", normalize: false},
                    {name: "District Cooling Mass Flow Rate", units: "kg/s", normalize: true},
                    {name: "District Heating Hot Water Rate", units: "W", normalize: false},
                    {name: "District Heating Mass Flow Rate", units: "kg/s", normalize: true}]
                    
      timeseries.each do |ts|
        makeSchedule(start_date, time_step, values[ts[:name]], model, basename, ts)
      end
    end
    
    # todo: create a plant loop
    
    return @result

  end
  
end

# register the measure to be used by the application
ImportDistrictSystemLoads.new.registerWithApplication
