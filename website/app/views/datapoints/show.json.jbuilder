json.set! :datapoint do
  json.set! :id, @datapoint.id.to_s
  json.extract! @datapoint, :created_at, :updated_at
  json.set! :feature_id, @datapoint.feature_id.to_s if @datapoint.feature
  json.set! :feature_type, @datapoint.feature.type.to_s if @datapoint.feature
  json.set! :option_set_id, @datapoint.option_set_id.to_s
  json.set! :workflow_id, @datapoint.option_set.workflow_id.to_s
  @datapoint.attributes.keys.each do |key|
    unless %w(created_at updated_at _id feature_id workflow_id).include? key
      json.set! key, @datapoint[key]
    end
  end
end
