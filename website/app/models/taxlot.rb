# Taxlot class
class Taxlot
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :lot_fid, type: String
  field :type, type: String
  field :region_id, type: String
  field :source_id, type: String
  field :source_name, type: String

  # Validation

  # Relations
  has_one :geometry, autosave: true, dependent: :destroy
  has_many :buildings, dependent: :destroy
  belongs_to :project

  # Indexes
  # TODO: add project_id to this index too
  index({ source_id: 1, source_name: 1 }, { unique: true })
  index({project_id: 1})
end
