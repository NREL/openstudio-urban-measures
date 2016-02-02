# Region class
class Region
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  # TODO: add ID field
  field :type, type: String
  field :region_id, type: String

  # Validation

  # Relations
  belongs_to :geometry
  belongs_to :user

end