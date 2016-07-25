json.array!(@workflows) do |workflow|
  json.set! :id, workflow.id.to_s
  json.set! :project_id, workflow.project.id.to_s
  json.set! :feature_type, workflow.feature_type.to_s
  json.url workflow_url(workflow, format: :json)
end
