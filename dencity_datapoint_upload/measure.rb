# Reporting measure to push structure hash to DEnCity server.

# Author: Henry Horsey (github: henryhorsey / rhorsey)
# Creation Date: 11/26/2015

require 'dencity'
require 'openstudio'
require 'multi_json'

class DencityDatapointUpload < OpenStudio::Ruleset::ReportingUserScript

  # Define the human-readable name
  def name
    'DEnCity Datapoint Upload'
  end

  # Define the arguments that the user will input
  def arguments
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # URL of the DEnCity server that will be posted to
    hostname = OpenStudio::Ruleset::OSArgument::makeStringArgument('hostname', true)
    hostname.setDisplayName('URL of the DEnCity Server')
    hostname.setDefaultValue('http://www.dencity.org')
    args << hostname

    # DEnCity server user id at hostname
    user_id = OpenStudio::Ruleset::OSArgument::makeStringArgument('user_id',true)
    user_id.setDisplayName('User ID for DEnCity Server')
    args << user_id

    # DEnCIty server user id's password
    auth_code = OpenStudio::Ruleset::OSArgument::makeStringArgument('auth_code', true)
    auth_code.setDisplayName('Authentication code for User ID on DEnCity server')
    args << auth_code

    # Building type for DEnCity's metadata
    building_type = OpenStudio::Ruleset::OSArgument::makeStringArgument('building_type', false)
    building_type.setDisplayName('Building type')
    args << building_type

    # HVAC system for DEnCity's metadata
    primary_hvac = OpenStudio::Ruleset::OSArgument::makeStringArgument('primary_hvac', false)
    primary_hvac.setDisplayName('Primary HVAC system in building')
    args << primary_hvac

    args

  end

  def run(runner, user_arguments)
    super(runner, user_arguments)

    # Use the built-in error checking
    unless runner.validateUserArguments(arguments, user_arguments)
      false
    end

    # Unpack DEnCity hostname, user_id, and auth_code
    hostname = runner.getStringArgumentValue('hostname', user_arguments)
    user_id = runner.getStringArgumentValue('user_id', user_arguments)
    auth_code = runner.getStringArgumentValue('auth_code', user_arguments)

    # Check connection to hostname and authenticate connection
    conn = Dencity.connect({host_name: hostname})
    runner.registerError "Could not connect to DEnCity server at #{hostname}." unless conn.connected?
    r = nil
    begin
      runner.registerInfo("Attempting to log into #{hostname} with user ID #{user_id}")
      r = conn.login(user_id, auth_code)
    rescue Faraday::ParsingError => user_id_failure
      runner.registerError "Error in user_id field: #{user_id_failure.message}"
    rescue MultiJson::ParseError => authentication_failure
      runner.registerError "Error in attempted authentication: #{authentication_failure.message}"
    end
    user_uuid = r.id

    # Unpack DEnCity metadata fields
    building_type = runner.getOptionalStringArgumentValue('building_type', user_arguments)
    building_type.is_initialized ? building_type = building_type.get : building_type = nil
    primary_hvac = runner.getOptionalStringArgumentValue('primary_hvac', user_arguments)
    primary_hvac.is_initialized ? primary_hvac = primary_hvac.get : primary_hvac = nil

    # Check that the analysis has already been registered with the DEnCity instance. This should be replaced with a
    # 'retrieve_analysis_by_user_defined_id' method in the future
    local_analysis_uuid = runner.analysis[:analysis][:_id]
    user_analyses = []
    r = conn.dencity_get 'analyses'
    runner.registerError('Unable to retrieve analyses from DEnCity server') unless r['status'] == 200
    r['data'].each do |analysis|
      user_analyses << analysis['id'] if analysis['user_id'] == user_uuid
    end
    found_analysis_uuid = false
    dencity_id = ''
    user_analyses.each do |analysis_id|
      analysis = conn.retrieve_analysis_by_id(analysis_id)
      if analysis['user_defined_id'] == local_analysis_uuid
        dencity_id = analysis['id']
        found_analysis_uuid = true
        break
      end
    end

    # Error if the analysis json cannot be found
    runner.registerError('Unable to find the analysis uuid in the DEnCity database.') unless found_analysis_uuid

    # Parse out the measure_instance data from the analysis and datapoint hashes
    structure_hash = {}
    datapoint = runner.datapoint[:data_point]
    var_uuid_hash = datapoint[:set_variable_values]
    analysis = runner.analysis[:analysis]
    measure_instances = []
    if analysis[:problem][:workflow]
      analysis[:problem][:workflow].each do |wf|
        m_instance = {}
        m_instance['uri'] = 'https://bcl.nrel.gov or file:///local'
        m_instance['id'] = wf[:measure_definition_uuid]
        m_instance['version_id'] = wf[:measure_definition_version_uuid]
        if wf[:arguments]
          m_instance[:arguments] = {}
          if wf[:variables]
            wf[:variables].each do |var|
              m_instance[:arguments][var[:argument][:name]] = var_uuid_hash[var[:uuid].to_sym]
            end
          end
          wf[:arguments].each do |arg|
            m_instance[:arguments][arg[:name]] = arg[:value]
          end
        end

        measure_instances << m_instance
      end
    end
    structure_hash['measure_instances'] = measure_instances

    # Check for available results to push into the database
    structure_results = {}
#=begin
    measure_results = runner.past_results
    runner.registerInfo("Previous results keys: #{measure_results.keys}")
    if measure_results.keys.include? 'dencity_reports'.to_sym
      results_to_parse = measure_results['dencity_reports'.to_sym]
      results_to_parse.keys.each do |res|
        next if res.to_s.include? 'units'
        puts "res: #{res}"
        puts "results_to_parse[res]: #{results_to_parse[res]}"
        structure_results[res.to_s] = results_to_parse[res].to_s
      end
    else
      runner.registerInfo('Could not find dencity_reports key in results hash. Not attaching results metadata.')
    end
    structure_results['building_type'] = building_type if building_type != nil
    structure_results['primary_hvac'] = primary_hvac if primary_hvac != nil
    structure_hash['structure'] = structure_results
#=end

    # Write the datapoint's structure_hash to structure.json
    f = File.open('structure.json', 'wb')
    f.write(MultiJson.dump(structure_hash, :pretty => true))
    f.close

    # Push the structure.json file to DEnCity
    structure = conn.load_structure(dencity_id, runner.datapoint[:data_point][:_id], './structure.json')
    begin
      structure_response = structure.push
    rescue StandardError => e
      runner.registerError("Upload failure: #{e.message} in #{e.backtrace.join('/n')}")
    else
      if structure_response.status.to_s[0] == '2'
        runner.registerInfo('Successfully uploaded processed structure json file to the DEnCity server.')
      else
        runner.registerError("ERROR: Server returned a non-2xx status. Response was: #{structure_response}")
      end
    end

    # Register the structure id so that other measures can upload files to the structure
    runner.registerValue("structure_id", "Structure ID", structure_response.structure.id)

    true

  end

end

DencityDatapointUpload.new.registerWithApplication