json.array!(@datapoints) do |datapoint|
  json.set! :id, datapoint.id.to_s
  json.set! :project_id, datapoint.project.id.to_s
  json.set! :feature_id, datapoint.feature.id.to_s if datapoint.feature
  json.set! :feature_type, datapoint.feature.type.to_s if datapoint.feature
  json.set! :option_set_id, datapoint.option_set_id.to_s
  json.url datapoint_url(datapoint, format: :json)
end
