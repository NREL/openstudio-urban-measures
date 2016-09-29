class Project
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :name, type: String

  # Relations
  has_many :workflows, dependent: :destroy
  has_many :scenarios, dependent: :destroy
  has_many :features, dependent: :destroy
  has_many :option_sets, dependent: :destroy
  has_many :geometries
  has_many :datapoints
  
  belongs_to :user

  # Indexes
  index({user_id: 1})

end
