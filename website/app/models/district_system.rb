# District system class
class DistrictSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  # TODO: add ID field
  field :type, type: String
  field :region_id, type: String

  # Validation

  # Relations
  belongs_to :geometry

end