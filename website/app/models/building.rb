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
  belongs_to :geometry
  has_many :datapoints
  belongs_to :user

end

