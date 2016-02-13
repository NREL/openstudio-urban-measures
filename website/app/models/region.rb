# Region class
class Region
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  # TODO: add ID field
  field :type, type: String
  field :region_id, type: String
  field :state_abbr, type: String
  field :state_name, type: String

  # Validation

  # Relations
  has_one :geometry, autosave: true, dependent: :destroy
  belongs_to :user

end