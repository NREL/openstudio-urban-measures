json.array!(@datapoints) do |datapoint|
  json.extract! datapoint, :id
  json.url datapoint_url(datapoint, format: :json)
end
