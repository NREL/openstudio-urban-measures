json.array!(@datapoints) do |datapoint|
  json.set! :id, datapoint.id.to_s
  json.url datapoint_url(datapoint, format: :json)
end
