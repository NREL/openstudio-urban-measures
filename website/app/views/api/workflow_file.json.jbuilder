json.set! :id, @workflow.workflow_file.id.to_s
json.set! :workflow_id, @workflow.id.to_s
json.extract! @workflow.workflow_file, :file_name, :file_size, :uri, :created_at, :updated_at
