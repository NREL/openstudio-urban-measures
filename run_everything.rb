require 'rest-client'
require 'parallel'
require 'json'

require_relative 'runner'

url = 'http://localhost:3000'
#url = 'http://insight4.hpc.nrel.gov:8081'
project_id = '57a904a5fbc99f774800010f'
user_name = 'test@nrel.gov'
user_pwd = 'testing123'
max_datapoints = Float::INFINITY
#max_datapoints = 2
num_parallel = 7

runner = Runner.new(url, project_id, user_name, user_pwd, max_datapoints, num_parallel)
runner.clear_results
dirs = runner.create_osws
runner.run_osws(dirs)
runner.save_results
