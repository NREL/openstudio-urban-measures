class Feature
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :type, type: String #Building, Taxlot, Region, District System, Street, Image, Other
  field :source_id, type: String
  field :source_name, type: String

  # Validation
  validates_presence_of :type

  # Relations
  has_one :geometry, autosave: true, dependent: :destroy
  has_many :datapoints, dependent: :destroy
  belongs_to :project

  # Indexes
  index({ source_id: 1, source_name: 1 }, { unique: true })
  index({project_id: 1})

end