json.set! :workflow do
  json.set! :id, @workflow.id.to_s
  json.extract! @workflow, :created_at, :updated_at

  @workflow.attributes.keys.each do |key|
    unless %w(created_at updated_at _id workflow_file).include? key
      json.set! key, @workflow[key]
    end
  end
  if @workflow.workflow_file
    json.set! :workflow_file do
      @workflow.workflow_file.attributes.each do |k, v|
        if k == '_id'
          json.set! :id, v.to_s
          @file_id = v.to_s
        elsif k == 'uri'
          json.set! :uri, download_zipfile_workflow_url(@workflow.id)
        else
          json.set! k, v
        end
      end
    end
  end
end
