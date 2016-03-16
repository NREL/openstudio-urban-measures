def get_all_building_ids()
  return []
end

def get_all_workflow_ids()
  return []
end

def get_datapoint(building_id, workflow_id)
  return {}
end

def get_workflow(datapoint_id)
  return {}
end

def run(workflow)

end

def post_datapoint_success(workflow)

end

def post_datapoint_failed(workflow)

end

# connect to database, get list of all building and workflow ids
all_building_ids = get_all_building_ids
all_workflow_ids = get_all_workflow_ids

# loop over all combinations
all_building_ids.each do |building_id|
  all_workflow_ids.each do |workflow_id|
    
    # get data point for each pair of building_id, workflow_id
    # data point is created if it doesn't already exist
    datapoint = get_datapoint(building_id, workflow_id)
    
    # check if this already has dencity results or is queued to run
    if !datapoint[:dencity_id].nil? || datapoint[:status] == "Queued"
      next
    end
    
    # datapoint is not run, get the workflow
    # this is the merged workflow with the building properties merged in to the template workflow
    workflow = get_workflow(datapoint_id)

    # save workflow
    File.open("./runs/#{workflow[:id]}.osw", 'w') do |file|
      file << workflow
    end
    
  end
end


Dir.glob("./runs/*.osw").each do |osw_path|

  workflow = JSON::load(osw_path)

  begin
    # run the osw
    run(workflow)
    
    dencity_id = nil
    
    # things worked, post back to the database that this datapoint is done and point to dencity id
    post_datapoint_success(workflow, dencity_id)
  rescue
  
    # things broke, post back to the database that this datapoint failed
    post_datapoint_failed(workflow)
  end
  
end