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

  # Relations
  belongs_to :building
  belongs_to :template_workflow, class_name: 'Workflow'
  belongs_to :instance_workflow, class_name: 'Workflow'
  belongs_to :user

end
