json.set! :option_set do
  json.set! :id, @option_set.id.to_s
  json.extract! @option_set, :created_at, :updated_at
  json.set! :project_id, @option_set.project_id.to_s
  json.set! :workflow_id, @option_set.workflow_id.to_s
  @option_set.attributes.keys.each do |key|
    unless %w(created_at updated_at _id project_id workflow_id).include? key
      json.set! key, @option_set[key]
    end
  end
end