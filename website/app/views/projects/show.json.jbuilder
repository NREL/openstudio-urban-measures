json.set! :project do
  json.set! :id, @project.id.to_s
	json.extract! @project, :created_at, :updated_at
	json.set! :user_id, @project.user_id.to_s
  @project.attributes.keys.each do |key|
    unless %w(created_at updated_at _id  user_id).include? key
      json.set! key, @project[key]
    end
  end
end

