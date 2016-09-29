class Scenario
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String

  belongs_to :project
  has_and_belongs_to_many :datapoints, autosave: true


end
