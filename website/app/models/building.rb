# Building model
class Building
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :type, type: String
  field :region_id, type: String
  field :taxlot_id, type: String
  field :source_id, type: String
  field :source_name, type: String

  # Validation

  # Relations
  has_one :geometry, autosave: true, dependent: :destroy
  has_many :datapoints, dependent: :destroy
  belongs_to :user

  # Indexes
  # TODO: add project_id to this index too
  index({ source_id: 1, source_name: 1 }, { unique: true })

end
