# Datapoint model
class Datapoint
  include Mongoid::Document
  include Mongoid::Timestamps

  #field :dencity_id, type: String
  #field :dencity_url, type: String
  #field :analysis_id, type: String # where does this come from? another model?
  field :timestamp_started, type: DateTime
  field :timestamp_completed, type: DateTime
  #field :variable_values, type: Array
  field :results, type: Hash
  field :status, type: String

  attr_accessor :file

  # Relations
  belongs_to :feature
  belongs_to :option_set
  belongs_to :project
  
  # DLM: for district system datapoints we want to ensure that they are in only one scenario
  has_and_belongs_to_many :scenario, autosave: true

  # Relations
  embeds_many :datapoint_files do
    def find_by_file_name(file_name)
      where(file_name: file_name).first
    end
  end

  def self.create_update_datapoint(data, datapoint, project_id)
    error = false
    error_message = ''

    data.each do |key, value|
      if key == 'id'
        # in case there's an ID in the file, and an id already defined on workflow
        if datapoint.id.to_s != value
          error = true
          error_message = 'ID in JSON file does not match ID of datapoint to update; canceling update.'
          break
        end
      else
        # TODO: should make sure there is a feature_id and an option_set_id (unique keys)
        datapoint[key] = value
      end
    end
    datapoint.project_id = project_id

    unless error

      unless datapoint.save!
        error = true
        error_message += "Could not process: #{datapoint.errors}."
      end
    end
    [datapoint, error, error_message]
  end

  def self.add_datapoint_file(file, filename, datapoint, is_api = false)
    error = false
    error_message = ''

    # first check that file_name is unique
    res = datapoint.datapoint_files.where(file_name: filename)
    res.each {|f| f.destroy}
    #if res.size > 0
    #  error = true
    #  error_message = 'There is already a file uploaded with this file_name.'
    #end

    unless error

      # Overwrite file if one already exists
      file_uri = "#{DATAPOINT_FILES_BASIC_PATH}#{datapoint.id}/#{filename}"
      FileUtils.mkpath("#{Rails.root}#{DATAPOINT_FILES_BASIC_PATH}") unless Dir.exist?("#{Rails.root}#{DATAPOINT_FILES_BASIC_PATH}")
      Dir.mkdir("#{Rails.root}#{DATAPOINT_FILES_BASIC_PATH}#{datapoint.id}/") unless Dir.exist?("#{Rails.root}#{DATAPOINT_FILES_BASIC_PATH}#{datapoint.id}/")

      the_file = File.open("#{Rails.root}/#{file_uri}", 'wb') do |f|
        if is_api
          f.write(Base64.strict_decode64(file))
        else
          f.write(file.read)
        end
      end

      df, error, error_message = DatapointFile.add_from_path(file_uri)
    end

    unless error

      datapoint.datapoint_files << df

      unless datapoint.save!
        error = true
        error_message += "Could not save zip file to datapoint #{datapoint.errors}"
      end
    end

    [datapoint, error, error_message]
  end

  def self.get_file_data(file)
    begin
      file_data = nil
      raise 'File not stored on the server' unless File.exist?("#{Rails.root}#{file.uri}")
      file_data = File.read("#{Rails.root}#{file.uri}")

      raise "Could not find file to download #{file.uri}" if file_data.nil?
    rescue => e
      flash[:notice] = "Could not find file to download #{file.uri}. #{e.message}"
      logger.error "Could not find file to download #{file.uri}. #{e.message}"
      redirect_to(:back)
    end
    file_data
  end

end
