json.array!(@workflows) do |workflow|
  json.set! :id, workflow.id.to_s
  json.extract! workflow, :type
  json.url workflow_url(workflow, format: :json)
end
