json.array!(@datapoints) do |datapoint|
  json.set! :id, datapoint.id.to_s
  json.set! :project_id, datapoint.project.id.to_s
  json.set! :building_id, datapoint.building.id.to_s if datapoint.building
  json.set! :workflow_id, datapoint.workflow.id.to_s
  json.url datapoint_url(datapoint, format: :json)
end
