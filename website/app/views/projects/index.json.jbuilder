json.array!(@projects) do |project|
  json.set! :id, project.id.to_s
  json.url project_url(project, format: :json)
end
