# Datapoint model
class Datapoint
  include Mongoid::Document
  include Mongoid::Timestamps

  field :dencity_id, type: String
  field :dencity_url, type: String
  field :analysis_id, type: String # where does this come from? another model?
  field :timestamp_started, type: DateTime
  field :timestamp_completed, type: DateTime
  field :variable_values, type: Array
  field :results, type: Array
  field :status, type: String

  # Relations
  belongs_to :building
  belongs_to :workflow
  belongs_to :project

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
end
