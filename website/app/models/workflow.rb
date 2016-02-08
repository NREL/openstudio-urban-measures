# Workflow model
class Workflow
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String  # template, instance

  # Relations
  embeds_one :workflow_file do
    def find_by_file_name(file_name)
      where(file_name: file_name).first
    end
  end
  has_many :datapoints # one instance and one template
  belongs_to :user

  def self.create_update_workflow(data, workflow)
  	
  	error = false
    error_message = ''

  	data.each do |key, value|

      # TODO: hopefully this is temporary and id will be removed?  For now, ignore "id".
      unless key == 'id'
        workflow[key] = value
      end
    end

    # uploaded workflows are always templates
    workflow.type = 'template'

    unless workflow.save!
      error = true
      error_message += "Could not process: #{workflow.errors}."
    end

    return workflow, error, error_message

  end

  def self.add_workflow_file(zip_file, workflow)
    error = false
    error_message = ''

    # TODO: overwrite existing file automatically or fail?  Right now, overwrite.
    file_uri = "#{WORKFLOW_FILES_BASIC_PATH}#{workflow.id}/#{zip_file.original_filename}"
    FileUtils.mkpath("#{Rails.root}#{WORKFLOW_FILES_BASIC_PATH}") unless Dir.exist?("#{Rails.root}#{WORKFLOW_FILES_BASIC_PATH}")
    Dir.mkdir("#{Rails.root}#{WORKFLOW_FILES_BASIC_PATH}#{workflow.id}/") unless Dir.exist?("#{Rails.root}#{WORKFLOW_FILES_BASIC_PATH}#{workflow.id}/")

    the_file = File.open("#{Rails.root}/#{file_uri}", 'wb') do |f|
      f.write(zip_file.read)
    end
    
    wf, error, error_message = WorkflowFile.add_from_path(file_uri)
    
    unless error
      
      workflow.workflow_file = wf

      unless workflow.save!
        error = true
        error_message += "Could not save zip file to workflow #{workflow.errors}"
      end
    end

    return workflow, error, error_message

  end


end
