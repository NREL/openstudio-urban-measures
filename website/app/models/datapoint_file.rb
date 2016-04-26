# Workflow File class
class DatapointFile
  include Mongoid::Document
  include Mongoid::Timestamps

  field :file_name, type: String
  field :file_size, type: Integer # KB
  field :uri, type: String

  embedded_in :datapoint

  validates_uniqueness_of :file_name, scope: :datapoint_id

  def self.add_from_path(file_path)
    error = false
    error_message = ''

    if File.exist? "#{Rails.root}/#{file_path}"
      new_path = "#{Rails.root}/#{file_path}"
      rf = DatapointFile.new
      rf.uri = file_path
      rf.file_name = File.basename(new_path)
      rf.file_size = (File.size(new_path) / 1024).to_i

    else
      error = true
      error_message = "Could not find file path: #{file_path} to add to DatapointFile"
      rf = nil
    end

    [rf, error, error_message]
  end
end
