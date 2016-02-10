# Building model
class Building
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :bldg_fid, type: String
  field :type, type: String
  field :region_id, type: String

  # Validation

  # Relations
  has_one :geometry, autosave: true, dependent: :destroy
  has_many :datapoints
  belongs_to :user

end

