# Workflow model
class Workflow
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String # template, instance

  # Relations
  embeds_one :workflow_file do
    def find_by_file_name(file_name)
      where(file_name: file_name).first
    end
  end

  belongs_to :user

  def self.create_update_workflow(data, workflow)
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

    unless error
      # uploaded workflows are always templates
      workflow.type = 'template'

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
end
