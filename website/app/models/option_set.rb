class OptionSet
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :color, type: String

  # Relations
  belongs_to :project
  belongs_to :workflow
  has_many :datapoints, dependent: :destroy

end
