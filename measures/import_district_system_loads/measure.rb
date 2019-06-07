######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

require 'json'
require 'net/http'
require 'base64'
require 'csv'

# start the measure
class ImportDistrictSystemLoads < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return 'Import District System Loads'
  end

  # human readable description
  def description
    return 'Imports District System Loads as Schedules'
  end

  # human readable description of modeling approach
  def modeler_description
    return ''
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # url of the city database
    city_db_url = OpenStudio::Measure::OSArgument.makeStringArgument('city_db_url', true)
    city_db_url.setDisplayName('City Database Url')
    city_db_url.setDescription('Url of the City Database')
    # city_db_url.setDefaultValue("http://localhost:3000")
    city_db_url.setDefaultValue('http://insight4.hpc.nrel.gov:8081/')
    args << city_db_url

    # project id
    project_id = OpenStudio::Measure::OSArgument.makeStringArgument('project_id', true)
    project_id.setDisplayName('Project ID')
    project_id.setDescription('Project ID.')
    args << project_id

    # scenario id
    scenario_id = OpenStudio::Measure::OSArgument.makeStringArgument('scenario_id', true)
    scenario_id.setDisplayName('Scenario ID')
    scenario_id.setDescription('Scenario ID.')
    args << scenario_id

    # feature id
    feature_id = OpenStudio::Measure::OSArgument.makeStringArgument('feature_id', true)
    feature_id.setDisplayName('Feature ID')
    feature_id.setDescription('Feature ID.')
    args << feature_id

    return args
  end

  # get the feature from the database
  def get_feature(project_id, feature_id)
    http = Net::HTTP.new(@city_db_url, @port)
    http.read_timeout = 1000
    if @city_db_is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Get.new("/api/feature.json?project_id=#{project_id}&feature_id=#{feature_id}")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])

    response = http.request(request)
    if response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      @result = false
      return {}
    end

    result = JSON.parse(response.body, symbolize_names: true)
    return result
  end

  # get the project from the database
  def get_datapoint_ids(project_id, scenario_id)
    http = Net::HTTP.new(@city_db_url, @port)
    http.read_timeout = 1000
    if @city_db_is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Get.new("/api/retrieve_scenario.json?project_id=#{project_id}&scenario_id=#{scenario_id}")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])

    response = http.request(request)
    if response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      @result = false
    end

    scenario = JSON.parse(response.body, symbolize_names: true)
    datapoints = scenario[:scenario][:datapoints]

    result = []
    if datapoints.nil?
      @runner.registerError("Scenario #{scenario_id} has no datapoints")
      @result = false
    else
      datapoints.each do |datapoint|
        if datapoint[:feature_type] == 'Building'
          result << datapoint[:id]
        end
      end
    end

    return result
  end

  def download_datapoint(project_id, datapoint_id)
    http = Net::HTTP.new(@city_db_url, @port)
    http.read_timeout = 1000
    if @city_db_is_https
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Get.new("/api/retrieve_datapoint.json?project_id=#{project_id}&datapoint_id=#{datapoint_id}")
    request.add_field('Content-Type', 'application/json')
    request.add_field('Accept', 'application/json')
    request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])

    response = http.request(request)
    if response.code != '200' # success
      @runner.registerError("Bad response #{response.code}")
      @runner.registerError(response.body)
      @result = false
    end

    datapoint = JSON.parse(response.body, symbolize_names: true)[:datapoint]
    datapoint_files = datapoint[:datapoint_files]
    if datapoint_files
      datapoint_files.each do |datapoint_file|
        if /datapoint_reports_report\.csv/.match(datapoint_file[:file_name])
          file_name = datapoint_file[:file_name]
          file_id = datapoint_file[:_id][:$oid]

          http = Net::HTTP.new(@city_db_url, @port)
          http.read_timeout = 1000
          if @city_db_is_https
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end

          request = Net::HTTP::Get.new("/api/retrieve_datapoint_file.json?project_id=#{project_id}&datapoint_id=#{datapoint_id}&file_name=#{file_name}")
          request.basic_auth(ENV['URBANOPT_USERNAME'], ENV['URBANOPT_PASSWORD'])

          response = http.request(request)
          if response.code != '200' # success
            @runner.registerError("Bad response #{response.code}")
            @runner.registerError(response.body)
            @result = false
          end

          file_data = JSON.parse(response.body, symbolize_names: true)[:file_data]
          file = Base64.strict_decode64(file_data[:file])

          # DLM: not sure why line endings are being changed on upload/download, correct them here for now
          file.gsub!("\r\n", "\n")

          filename = "#{datapoint_id}_timeseries.csv"
          File.open(filename, 'w') do |f|
            f.write(file)
          end
          return filename
        end
      end
    end

    return nil
  end

  def makeSchedule(start_date, time_step, values, model, basename, ts)
    if values.nil?
      return
    end

    if ts[:name].include? 'Mass Flow Rate'
      values *= 0.001 # kg to m^3 of water, which is 1000 kg/m^3
    end

    maximum = OpenStudio.maximum(values)
    minimum = OpenStudio.minimum(values)
    if ts[:normalize]
      n = values.size
      (0...n).each do |i|
        if maximum == 0
          values[i] = 0
        else
          values[i] = values[i] / maximum
        end
      end
    end

    name = "#{basename} #{ts[:name]}"
    if maximum == minimum
      schedule = OpenStudio::Model::ScheduleConstant.new(model)
      schedule.setValue(maximum)
    else
      mult = 1
      if ts[:name].include? 'District Cooling Chilled Water Rate'
        mult = -1
      end
      timeseries = OpenStudio::TimeSeries.new(start_date, time_step, values * mult, ts[:units])
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
    city_db_url = runner.getStringArgumentValue('city_db_url', user_arguments)
    project_id = runner.getStringArgumentValue('project_id', user_arguments)
    scenario_id = runner.getStringArgumentValue('scenario_id', user_arguments)
    feature_id = runner.getStringArgumentValue('feature_id', user_arguments)

    @runner = runner
    @result = true

    uri = URI.parse(city_db_url)
    @city_db_url = uri.host
    @port = uri.port
    @city_db_is_https = uri.scheme == 'https'

    feature = get_feature(project_id, feature_id)
    if feature[:properties].nil? || feature[:properties][:district_system_type].nil?
      runner.registerError("Cannot get feature #{feature_id} missing required property district_system_type")
      return false
    end

    district_system_type = feature[:properties][:district_system_type]
    if district_system_type == 'Community Photovoltaic'
      # add in geometry for PV, maybe this should happen in add geometry measure?  add to this workflow?
      vertices = OpenStudio::Point3dVector.new
      vertices << OpenStudio::Point3d.new(0, 1, 0)
      vertices << OpenStudio::Point3d.new(0, 0, 0)
      vertices << OpenStudio::Point3d.new(1, 0, 0)
      vertices << OpenStudio::Point3d.new(1, 1, 0)
      surface = OpenStudio::Model::ShadingSurface.new(vertices, model)

      shading_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      surface.setShadingSurfaceGroup(shading_group)

      runner.registerInfo("No need to import loads for district system type '#{district_system_type}'")
      return true
    end

    datapoint_ids = get_datapoint_ids(project_id, scenario_id)

    datapoint_files = []
    datapoint_ids.each do |datapoint_id|
      datapoint_file = download_datapoint(project_id, datapoint_id)
      if datapoint_file
        datapoint_files << datapoint_file
      end
    end

    # get timesteps
    time_step_per_hour = model.getTimestep.numberOfTimestepsPerHour
    num_rows = 8760 * time_step_per_hour
    start_date = model.getYearDescription.makeDate(1, 1)
    time_step = OpenStudio::Time.new(0, 0, 60 / time_step_per_hour, 0)

    timeseries = [{ name: 'District Cooling Chilled Water Rate', units: 'W', normalize: false },
                  { name: 'District Cooling Mass Flow Rate', units: 'kg/s', normalize: true },
                  { name: 'District Heating Hot Water Rate', units: 'W', normalize: false },
                  { name: 'District Heating Mass Flow Rate', units: 'kg/s', normalize: true }]

    summed_values = {}
    datapoint_files.each do |file|
      runner.registerInfo("Reading #{file}")

      basename = File.basename(file, '.csv').gsub('_timeseries', '')

      i = 0
      headers = []
      values = {}
      CSV.foreach(file) do |row|
        if i == 0
          # header row
          headers = row
          headers.each do |header|
            values[header] = OpenStudio::Vector.new(num_rows, 0.0)
            if summed_values[header].nil?
              summed_values[header] = OpenStudio::Vector.new(num_rows, 0.0)
            end
          end
        elsif i <= num_rows
          headers.each_index do |j|
            v = row[j].to_f
            values[headers[j]][i - 1] = v
            summed_values[headers[j]][i - 1] = summed_values[headers[j]][i - 1] + v
          end
        end
        i += 1
      end

      # to make one individual schedules
      # timeseries.each do |ts|
      #  makeSchedule(start_date, time_step, values[ts[:name]], model, basename, ts)
      # end
    end

    # to make one summed schedule
    timeseries.each do |ts|
      makeSchedule(start_date, time_step, summed_values[ts[:name]], model, 'Summmed', ts)
    end

    # TODO: create a plant loop

    return @result
  end
end

# register the measure to be used by the application
ImportDistrictSystemLoads.new.registerWithApplication
