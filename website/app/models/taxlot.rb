# Taxlot class
class Taxlot
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :lot_fid, type: String
  field :type, type: String
  field :region_id, type: String

  # Validation

  # Relations
  has_one :geometry, autosave: true, dependent: :destroy
  belongs_to :user

end