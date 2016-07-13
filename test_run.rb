# this example runs without using the web interface to query input data

require 'json'
require 'parallel'
require 'fileutils'

include = ""
#openstudio_2_0 = "E:/openstudio-2-0/build"
#include = "-I '#{File.join(openstudio_2_0, 'OSCore-prefix/src/OSCore-build/ruby/Debug/')}"

run_retrofit = false
num_parallel = 7

buildings = [
  # {name: "Large-Office",             building_type: "Office",                        floor_area: 46320,  number_of_stories: 12}, # PAT success, example_run FAILURE
   {name: "Medium-Office",            building_type: "Office",                        floor_area: 4982,   number_of_stories: 3},  # PAT success, example_run success
  # {name: "Small-Office",             building_type: "Office",                        floor_area: 511,    number_of_stories: 1},  # PAT success, example_run success
  # {name: "Warehouse",                building_type: "Nonrefrigerated warehouse",     floor_area: 4835,   number_of_stories: 1},  # PAT success, example_run success
  # {name: "StandaloneRetail",         building_type: "Retail other than mall",        floor_area: 2319,   number_of_stories: 1},  # PAT success, example_run success
  # {name: "Strip-Mall",               building_type: "Strip shopping mall",           floor_area: 2090,   number_of_stories: 1},  # PAT success, example_run success
  # {name: "Primary-School",           building_type: "Education",                     floor_area: 6871,   number_of_stories: 1},  # PAT success, example_run success
  # {name: "Secondary-School",         building_type: "Education",                     floor_area: 19592,  number_of_stories: 2},  # PAT success, example_run success
  # {name: "Supermarket",              building_type: "Food sales",                    floor_area: 4180,   number_of_stories: 1},  # PAT success, example_run success
  # {name: "Quick-Service-Restaurant", building_type: "Food service",                  floor_area: 232,    number_of_stories: 1},  # PAT success, example_run success
  # {name: "Full-Service-Restaurant",  building_type: "Food service",                  floor_area: 511,    number_of_stories: 1},  # PAT success, example_run success
  # {name: "Hospital",                 building_type: "Inpatient health care",         floor_area: 22422,  number_of_stories: 5},  # PAT success, example_run FAILURE
  # {name: "Outpatient-Health-Care",   building_type: "Outpatient health care",        floor_area: 3804,   number_of_stories: 3},  # PAT success, example_run success
  # {name: "Small-Hotel",              building_type: "Lodging",                       floor_area: 4013,   number_of_stories: 4},  # PAT success, example_run success
  # {name: "Large-Hotel",              building_type: "Lodging",                       floor_area: 11345,  number_of_stories: 6},  # PAT success, example_run FAILURE
  # {name: "Midrise-Apartment",        building_type: "Multifamily (5 or more units)", floor_area: 3134,   number_of_stories: 4,  number_of_residential_units: 24}, # PAT success, example_run success
  # {name: "Single-Family",            building_type: "Single-Family",                 floor_area: 200,    number_of_stories: 2,  number_of_residential_units: 1}, # PAT success, example_run success
  # {name: "Multifamily-4",            building_type: "Multifamily (2 to 4 units)",    floor_area: 800,    number_of_stories: 2,  number_of_residential_units: 4}, # PAT success, example_run success
  # {name: "Multifamily-8",            building_type: "Multifamily (5 or more units)", floor_area: 1600,   number_of_stories: 3,  number_of_residential_units: 8}, # PAT success, example_run success
  # {name: "Mobile-Home",              building_type: "Mobile Home",                   floor_area: 80,     number_of_stories: 1,  number_of_residential_units: 1}, # failure (graceful)
   {name: "Mixed-use",                building_type: "Mixed use",                     floor_area: 4013,   number_of_stories: 4,  number_of_residential_units: 15, mixed_types: JSON::generate([{percent_floor_area: 25, building_type: "StandaloneRetail"},{percent_floor_area: 75, building_type: "Multifamily (5 or more units)"}])}, # 
  # {name: "Mixed-use-2",              building_type: "Mixed use",                     floor_area: 4013,   number_of_stories: 4,  number_of_residential_units: 12, mixed_types: JSON::generate([{percent_floor_area: 40, building_type: "StandaloneRetail"},{percent_floor_area: 60, building_type: "Multifamily (5 or more units)"}])} # 
]

#buildings = [buildings[0]]

def merge(workflow, properties)
  workflow[:steps].each do |step|
    arguments = step[:arguments]
    arguments.each_key do |name|
      if properties[name]
        value = properties[name]
        puts "Setting '#{name}' of '#{step[:measure_dir_name]}' to '#{value}'"
        arguments[name] = value
      end
    end
  end
  return workflow
end

# configure a workflow with building data
def configure(workflow, datapoint, building, region)

  # configure with region first
  workflow = merge(workflow, region[:properties])

  # configure with building next
  workflow = merge(workflow, building[:properties])
  
  # configure with datapoint last
  workflow = merge(workflow, datapoint)
  
  # weather_file comes from the region properties
  workflow[:weather_file] = region[:properties][:weather_file_name]
  
  return workflow
end

Parallel.each(buildings, in_threads: num_parallel) do |building|
#buildings.each do |building|

  # configure jsons
  datapoint_json = {:properties=>{}}
  building_json = {:properties=>building}
  region_json = {:properties=>{:weather_file_name => "USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw"}}

  name = building[:name]

  # load the workflows
  baseline_osw = nil
  File.open(File.join(File.dirname(__FILE__), "/workflows/testing_baseline.osw"), 'r') do |f|
    baseline_osw = JSON::parse(f.read, :symbolize_names => true)
  end
    
  retrofit_osw = nil
  File.open(File.join(File.dirname(__FILE__), "/workflows/testing_retrofit.osw"), 'r') do |f|
    retrofit_osw = JSON::parse(f.read, :symbolize_names => true)
  end

  # configure the osws with jsons
  baseline_osw = configure(baseline_osw, datapoint_json, building_json, region_json)
  retrofit_osw = configure(retrofit_osw, datapoint_json, building_json, region_json)

  # set up the directories
  baseline_osw_dir = File.join(File.dirname(__FILE__), "/run/testing_#{name}/baseline/")
  FileUtils.rm_rf(baseline_osw_dir)
  FileUtils.mkdir_p(baseline_osw_dir)

  retrofit_osw_dir = File.join(File.dirname(__FILE__), "/run/testing_#{name}/retrofit/")
  FileUtils.rm_rf(retrofit_osw_dir)
  FileUtils.mkdir_p(retrofit_osw_dir) if run_retrofit
  
  # save the configured osws
  baseline_osw_path = "#{baseline_osw_dir}/in.osw"
  File.open(baseline_osw_path, 'w') do |f|
    f << JSON.generate(baseline_osw)
  end
    
  if run_retrofit
    retrofit_osw_path = "#{retrofit_osw_dir}/in.osw"
    File.open(retrofit_osw_path, 'w') do |f|
      f << JSON.generate(retrofit_osw)
    end
  end
    
  # run them
  run_script = File.join(File.dirname(__FILE__), "run.rb")

  command = "bundle exec #{RbConfig.ruby} #{include} #{run_script} #{baseline_osw_path}"
  puts command
  system(command)

  if run_retrofit
    command = "bundle exec #{RbConfig.ruby} #{include} #{run_script} #{retrofit_osw_path}"
    puts command
    system(command)
  end
end