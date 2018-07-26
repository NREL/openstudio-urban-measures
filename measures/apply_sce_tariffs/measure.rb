# see the URL below for information on how to write OpenStuido measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# TODO	Remove all existing tariffs
# this is difficult to do in workspace, and not likely necessary.  Skipping for first version
# Add selected Xcel tariffs
# Set timestep to demand window
# TODO	Set economic parameters such as discount rate, etc to hard coded values (current NIST values for 2012)

# start the measure
class ApplySceTariffs < OpenStudio::Ruleset::WorkspaceUserScript


  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return "ApplySceTariffs"
  end

  # define the script arguments
  def arguments(workspace)
    args = OpenStudio::Measure::OSArgumentVector.new

    # tariff package choices

    tariff_labels = OpenStudio::StringVector.new
    tariff_files = OpenStudio::StringVector.new

    tariff_labels << 'Comm/Industrial TOU 8 B <2kV'
    tariff_files << 'sce_CI_TOU_8_B_less2kV'
    tariff_labels << 'Comm/Industrial TOU 8 B 2-50kV'
    tariff_files << 'sce_CI_TOU_8_B_2-50kV'
    tariff_labels << 'Comm/Industrial TOU-GS-3 <2kV'
    tariff_files << 'sce_CI_TOU_GS-3_less2kV'
    
    tariff_labels << 'Residential D Tiered'
    tariff_files << 'sce_res_d'
    tariff_labels << 'Residential D-Care Tiered'
    tariff_files << 'sce_res_d-care'
    tariff_labels << 'Residential D-FERA Tiered'
    tariff_files << 'sce_res_d-fera'

    tariff_labels << 'Residential TOU D-A'
    tariff_files << 'sce_res_tou_d-a'
    # tariff_labels << 'Residential TOU D-B'
    # tariff_files << 'sce_res_tou_d-b'
    # tariff_labels << 'Residential TOU 4-9'
    # tariff_files << 'sce_res_tou_4-9'
    # tariff_labels << 'Residential TOU 5-8'
    # tariff_files << 'sce_res_tou_5-8'

    tariff = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('tariff', tariff_files, tariff_labels, true)
    tariff.setDisplayName("Utility Rate Scheme")
    tariff.setDescription("")
    tariff.setDefaultValue("*None*")
    args << tariff

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get

    # assign the user inputs to variables
    elec_tariff = runner.getStringArgumentValue('tariff', user_arguments)
    #gas_tar = runner.getStringArgumentValue('gas_tar', user_arguments)

    # import the tariffs
    [elec_tariff].each do |tar|
      # load the idf file containing the electric tariff
      tar_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/resources/#{tar}.idf")
      tar_file = OpenStudio::IdfFile.load(tar_path)

      # in OpenStudio PAT in 1.1.0 and earlier all resource files are moved up a directory.
      # below is a temporary workaround for this before issuing an error.
      if tar_file.empty?
        tar_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{tar}.idf")
        tar_file = OpenStudio::IdfFile.load(tar_path)
      end

      if tar_file.empty?
        runner.registerError("Unable to find the tariff file (#{tar}.idf)")
        return false
      else
        tar_file = tar_file.get
      end

      # add entire contents of the idf
      workspace.addObjects(tar_file.objects)

      # info
      runner.registerInfo("added #{tar_file.numObjects} rate/tariff object(s) from file #{tar}.idf")

    end

    # use the simulation timestep
    timesteps_per_hour = model.getTimestep.numberOfTimestepsPerHour
    runner.registerInfo("Timesteps_per_hour is set to: #{timesteps_per_hour}")
    #add_result(results, "timesteps_per_hour", timesteps_per_hour, "")
    if !workspace.getObjectsByType('Timestep'.to_IddObjectType).empty?
      if !timesteps_per_hour.nil?
        workspace.getObjectsByType('Timestep'.to_IddObjectType)[0].setString(0, timesteps_per_hour.to_s)
      else
        workspace.getObjectsByType('Timestep'.to_IddObjectType)[0].setString(0, '4')
      end
      runner.registerInfo("set the simulation timestep to #{timesteps_per_hour}")
    else
      runner.registerError('there was no timestep object to alter')
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ApplySceTariffs.new.registerWithApplication
