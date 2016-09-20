require 'rest-client'
require 'parallel'
require 'json'

require_relative 'runner'

url = 'http://localhost:3000'
#url = 'http://insight4.hpc.nrel.gov:8081'
openstudio_dir = 'E:/openstudio-2-0/core-build/Products/Debug/'
project_id = '57aa050bfbc99f77480001a5'
user_name = 'test@nrel.gov'
user_pwd = 'testing123'
max_datapoints = Float::INFINITY
max_datapoints = 2
num_parallel = 1

runner = Runner.new(url, openstudio_dir, project_id, user_name, user_pwd, max_datapoints, num_parallel)
runner.clear_results
dirs = runner.create_osws
runner.run_osws(dirs)
runner.save_results
