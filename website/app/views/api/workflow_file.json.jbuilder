json.set! :id, @wf.id.to_s
json.set! :workflow_id, @workflow.id.to_s
json.extract! @wf, :file_name, :file_size, :file_type, :uri, :created_at, :updated_at
