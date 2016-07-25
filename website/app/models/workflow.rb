# Workflow model
class Workflow
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :display_name, type: String
  field :feature_type, type: String

  # Relations
  embeds_one :workflow_file do
    def find_by_file_name(file_name)
      where(file_name: file_name).first
    end
  end

  belongs_to :project
  has_many :datapoints, dependent: :destroy

  def self.create_update_workflow(data, workflow, project_id, name, display_name)
    error = false
    error_message = ''

    data.each do |key, value|
      if key == 'id'
        # in case there's an ID in the file, and an id already defined on workflow
        if workflow.id.to_s != value
          error = true
          error_message = 'ID in JSON file does not match ID of workflow to update; canceling update.'
          break
        end
      else
        workflow[key] = value
      end
    end
    workflow.project_id = project_id
    workflow.name = name if name
    workflow.display_name = display_name if display_name
    
    unless error

      unless workflow.save!
        error = true
        error_message += "Could not process: #{workflow.errors}."
      end
    end

    [workflow, error, error_message]
  end

  def self.add_workflow_file(zip_file, filename, workflow, is_api = false)
    error = false
    error_message = ''

    # Overwrite file if one already exists
    file_uri = "#{WORKFLOW_FILES_BASIC_PATH}#{workflow.id}/#{filename}"
    FileUtils.mkpath("#{Rails.root}#{WORKFLOW_FILES_BASIC_PATH}") unless Dir.exist?("#{Rails.root}#{WORKFLOW_FILES_BASIC_PATH}")
    Dir.mkdir("#{Rails.root}#{WORKFLOW_FILES_BASIC_PATH}#{workflow.id}/") unless Dir.exist?("#{Rails.root}#{WORKFLOW_FILES_BASIC_PATH}#{workflow.id}/")

    the_file = File.open("#{Rails.root}/#{file_uri}", 'wb') do |f|
      if is_api
        f.write(Base64.strict_decode64(zip_file))
      else
        f.write(zip_file.read)
      end
    end

    wf, error, error_message = WorkflowFile.add_from_path(file_uri)

    unless error

      workflow.workflow_file = wf

      unless workflow.save!
        error = true
        error_message += "Could not save zip file to workflow #{workflow.errors}"
      end
    end

    [workflow, error, error_message]
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

  # DLM: this should be a common utility method, put it in models?
  # Ideally this would recursively clean the object, seems like this should exist?
  def self.get_clean_hash(object)
    result = {}
    if object
      object.attributes.each do |key, value|
        # convert object ids to strings
        if key == '_id'
          result[:id] = value.to_s
        elsif value.class == BSON::ObjectId
          result[key.parameterize.underscore.to_sym] = value.to_s
        else
          result[key.parameterize.underscore.to_sym] = value
        end
      end
    end
    return result
  end

end
