# Workflow File class
class WorkflowFile
  include Mongoid::Document
  include Mongoid::Timestamps

  field :file_name, type: String
  field :file_size, type: Integer # KB
  field :uri, type: String

  embedded_in :workflow

  def self.add_from_path(file_path)
    error = false
    error_message = ''

    if File.exist? "#{Rails.root}/#{file_path}"
      new_path = "#{Rails.root}/#{file_path}"
      rf = WorkflowFile.new
      rf.uri = file_path
      rf.file_name = File.basename(new_path)
      rf.file_size = (File.size(new_path) / 1024).to_i

    else
      error = true
      error_message = "Could not find file path: #{file_path} to add to WorkflowFile"
      rf = nil
    end

    [rf, error, error_message]
  end
end
