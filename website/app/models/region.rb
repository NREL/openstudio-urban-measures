# Region class
class Region
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  # TODO: add ID field
  field :type, type: String
  field :region_id, type: String
  field :state_name, type: String
  field :source_id, type: String
  field :source_name, type: String

  # Validation

  # Relations
  has_one :geometry, autosave: true, dependent: :destroy
  belongs_to :project
  
  # Indexes
  # TODO: add project_id to this index too
  index({ source_id: 1, source_name: 1 }, { unique: true })
  index({project_id: 1})
end
