json.set! :datapoint do
  json.set! :id, @datapoint.id.to_s
  json.extract! @datapoint, :created_at, :updated_at
  json.set! :building_id, @datapoint.building_id.to_s
  json.set! :workflow_id, @datapoint.workflow_id.to_s
  @datapoint.attributes.keys.each do |key|
    unless %w(created_at updated_at _id building_id workflow_id).include? key
      json.set! key, @datapoint[key]
    end
  end
end
