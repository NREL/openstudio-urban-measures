# Workflow File class
class WorkflowFile
  include Mongoid::Document
  include Mongoid::Timestamps

  field :file_type, type: String # the kind of file (zip)
  field :file_name, type: String
  field :file_size, type: Integer # kb
  field :uri, type: String

  embedded_in :workflow

  def self.add_from_path(file_path)
    if File.exist? "#{Rails.root}/#{file_path}"
      new_path = "#{Rails.root}/#{file_path}"
      rf = WorkflowFile.new
      rf.uri = file_path
      rf.file_name = File.basename(new_path)
      rf.file_type = File.extname(rf.file_name).gsub('.', '').downcase
      rf.file_size = (File.size(new_path) / 1024).to_i

      return rf
    else
      logger.error "Could not find file path: #{file_path} to add to WorkflowFile"
    end

    false
  end
end
