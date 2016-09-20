require 'rest-client'
require 'parallel'
require 'json'

require_relative 'runner'

url = 'http://localhost:3000'
#url = 'http://insight4.hpc.nrel.gov:8081'
openstudio_dir = 'E:/openstudio-2-0/core-build/Products/Debug/'
user_name = 'test@nrel.gov'
user_pwd = 'testing123'
#max_datapoints = Float::INFINITY
max_datapoints = 2
num_parallel = 7
project_id = "578939a2c44c8d1b88000003"
datapoint_ids = ["57964c36c44c8d2298000002"]

runner = Runner.new(url, openstudio_dir, project_id, user_name, user_pwd, max_datapoints, num_parallel)
runner.clear_results(datapoint_ids)

dirs = []
datapoint_ids.each do |datapoint_id|
  dirs << runner.create_osw(datapoint_id)
end

runner.run_osws(dirs)
runner.save_results
