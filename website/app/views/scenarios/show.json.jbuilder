json.set! :scenario do
  json.set! :id, @scenario.id.to_s
  json.set! :name, @scenario.name.to_s
  json.set! :project_id, @scenario.project.id.to_s
  
  datapoints = []
  @scenario.datapoints.each do |datapoint|
    datapoints << {id: datapoint.id.to_s, feature_id: datapoint.feature_id.to_s, feature_type: datapoint.feature.type.to_s, option_set_id: datapoint.option_set_id.to_s}
  end
  json.set! :datapoints, datapoints
end
