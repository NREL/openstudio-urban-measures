json.array!(@workflows) do |workflow|
  json.extract! workflow, :id
  json.url workflow_url(workflow, format: :json)
end
