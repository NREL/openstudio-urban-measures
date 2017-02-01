require 'rest-client'
require 'parallel'
require 'json'

require_relative 'runner'

url = 'http://localhost:3000'
#url = 'http://insight4.hpc.nrel.gov:8081'

#openstudio_exe = 'E:/openstudio/build/Products/Debug/openstudio.exe'
openstudio_exe = 'C:/Program Files/OpenStudio 2.0.1/bin/openstudio.exe'

user_name = 'test@nrel.gov'
user_pwd = 'testing123'
#max_datapoints = Float::INFINITY
max_datapoints = 2
num_parallel = 7
project_id = '58914d416eeb8814e0000034'
datapoint_ids = ['58914dc06eeb8814e00000ac']

runner = Runner.new(url, openstudio_exe, project_id, user_name, user_pwd, max_datapoints, num_parallel)
runner.update_measures
runner.clear_results(datapoint_ids)

dirs = []
datapoint_ids.each do |datapoint_id|
  dirs << runner.create_osw(datapoint_id)
end

runner.run_osws(dirs)
#runner.save_results
