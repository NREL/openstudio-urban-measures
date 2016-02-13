# District system model
class DistrictSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  # TODO: add ID field
  field :type, type: String
  field :region_id, type: String

  # Validation

  # Relations
  has_one :geometry, autosave: true, dependent: :destroy
  belongs_to :user
end
