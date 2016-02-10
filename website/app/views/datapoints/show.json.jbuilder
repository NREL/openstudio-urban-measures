json.set! :datapoint do
  json.set! :id, @datapoint.id.to_s
  json.extract! @datapoint, :created_at, :updated_at
  json.set! :building_id, @datapoint.building_id.to_s
  json.set! :template_workflow_id, @datapoint.template_workflow_id.to_s
  json.set! :instance_workflow_id, @datapoint.instance_workflow_id.to_s
  @datapoint.attributes.keys.each do |key|
    unless %w(created_at updated_at _id building_id template_workflow_id instance_workflow_id).include? key
      json.set! key, @datapoint[key]
    end
  end
end

