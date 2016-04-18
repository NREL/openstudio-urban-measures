class Project
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :name, type: String
  field :display_name, type: String

  # Relations
  has_many :workflows, dependent: :destroy
  has_many :scenarios, dependent: :destroy
  has_many :buildings, dependent: :destroy
  has_many :district_systems, dependent: :destroy
  has_many :regions, dependent: :destroy
  has_many :taxlots, dependent: :destroy
  has_many :scenarios, dependent: :destroy
  belongs_to :user
  has_many :geometries
  has_many :datapoints

  # Indexes
  index({user_id: 1})

end
