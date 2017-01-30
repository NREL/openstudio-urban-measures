json.array!(@scenarios) do |scenario|
  json.set! :id, scenario.id.to_s
  json.set! :name, scenario.name.to_s
  json.set! :project_id, scenario.project.id.to_s
  json.url scenario_url(scenario, format: :json)
end