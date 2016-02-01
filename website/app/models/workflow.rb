# Workflow model
class Workflow
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String  # template, instance

  # Relations
  embeds_many :workflow_files do
    def find_by_file_name(file_name)
      where(file_name: file_name).first
    end
  end
  has_many :datapoints # one instance and one template

  def self.create_update_workflow(data, workflow)
  	
  	error = false
    error_message = ''

  	data.each do |key, value|
      workflow[key] = value
    end

    unless workflow.save!
      error = true
      error_message += "Could not process: #{wf.errors}."
    end

    return workflow, error, error_message

  end

end
