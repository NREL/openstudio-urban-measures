# this example runs without using the web interface to query input data

require 'json'
require 'parallel'
require 'fileutils'
require_relative 'config'

openstudio_exe = UrbanOptConfig::OPENSTUDIO_EXE

run_retrofit = false
num_parallel = 7
jobs = []

buildings = [
   # {name: "Large-Office",             building_type: "Office",                        total_bldg_area_ip: 300000, num_floors: 12},
   # {name: "Medium-Office",            building_type: "Office",                        total_bldg_area_ip: 80000,  num_floors: 3},
   # {name: "Small-Office",             building_type: "Office",                        total_bldg_area_ip: 5000,   num_floors: 1},
   # {name: "Warehouse",                building_type: "Nonrefrigerated warehouse",     total_bldg_area_ip: 52000,  num_floors: 1},
   # {name: "StandaloneRetail",         building_type: "Retail other than mall",        total_bldg_area_ip: 25000,  num_floors: 1},
   # {name: "Strip-Mall",               building_type: "Strip shopping mall",           total_bldg_area_ip: 23000,  num_floors: 1},
   # {name: "Primary-School",           building_type: "Education",                     total_bldg_area_ip: 74000,  num_floors: 1},
   # {name: "Secondary-School",         building_type: "Education",                     total_bldg_area_ip: 211000, num_floors: 2},
   # {name: "Supermarket",              building_type: "Food sales",                    total_bldg_area_ip: 45000,  num_floors: 1},
   # {name: "Quick-Service-Restaurant", building_type: "Food service",                  total_bldg_area_ip: 2500,   num_floors: 1},
   # {name: "Full-Service-Restaurant",  building_type: "Food service",                  total_bldg_area_ip: 5500,   num_floors: 1},
   # {name: "Hospital",                 building_type: "Inpatient health care",         total_bldg_area_ip: 241000, num_floors: 5},
   # {name: "Outpatient-Health-Care",   building_type: "Outpatient health care",        total_bldg_area_ip: 41000,  num_floors: 3},
   # {name: "Small-Hotel",              building_type: "Lodging",                       total_bldg_area_ip: 43000,  num_floors: 4},
   # {name: "Large-Hotel",              building_type: "Lodging",                       total_bldg_area_ip: 122000, num_floors: 6},
   # {name: "Single-Family",            building_type: "Single-Family",                 total_bldg_area_ip: 1600,   num_floors: 2,  number_of_residential_units: 1},
   {name: "Multifamily-4",            building_type: "Multifamily (2 to 4 units)",    total_bldg_area_ip: 5000,   num_floors: 2,  number_of_residential_units: 4},
   # {name: "Multifamily-8",            building_type: "Multifamily (5 or more units)", total_bldg_area_ip: 10000,  num_floors: 3,  number_of_residential_units: 8},
   # {name: "Mobile-Home",              building_type: "Mobile Home",                   total_bldg_area_ip: 800,    num_floors: 1,  number_of_residential_units: 1},
   # {name: "Mixed-use",                building_type: "Mixed use",                     total_bldg_area_ip: 43000,  num_floors: 4,  number_of_residential_units: 15, mixed_type_1: "Multifamily (5 or more units)", mixed_type_1_percentage: 75, mixed_type_2: "Retail other than mall", mixed_type_2_percentage: 25}, 
   # {name: "Mixed-use-2",              building_type: "Mixed use",                     total_bldg_area_ip: 43000,  num_floors: 4,  number_of_residential_units: 12, mixed_type_1: "Multifamily (5 or more units)", mixed_type_1_percentage: 60, mixed_type_2: "Food service", mixed_type_2_percentage: 40} 
]

buildings.each do |building|
  building[:heating_source] = "Gas" # NA, Gas, Electric, District Hot Water, District Ambient Water
  building[:cooling_source] = "Electric" # NA, Electric, District Chilled Water, District Ambient Water 
  building[:system_type] = "Forced air" # NA, Forced air, Hydronic
end

def merge(workflow, properties)
  workflow[:steps].each do |step|
    arguments = step[:arguments]
    arguments.each_key do |name|
      if properties[name]
        value = properties[name]
        #puts "Setting '#{name}' of '#{step[:measure_dir_name]}' to '#{value}'"
        arguments[name] = value
      end
    end
  end
  return workflow
end

# configure a workflow with building data
def configure(workflow, datapoint, building, region, skip_value)

  # configure with region first
  workflow = merge(workflow, region[:properties])

  # configure with building next
  workflow = merge(workflow, building[:properties])
  
  # configure with datapoint last
  workflow = merge(workflow, datapoint)
  
  # weather_file comes from the region properties
  workflow[:weather_file] = region[:properties][:weather_file_name]
  
  # remove keys with null values
  workflow[:steps].each do |step|
    arguments = step[:arguments]
    arguments.each_key do |name|
      if name == :__SKIP__
        #puts "setting skip #{skip_value}"
        arguments[name] = skip_value
      elsif arguments[name].nil?
        arguments.delete(name)
      end 
    end
  end
  
  return workflow
end

buildings.each do |building|

  # configure jsons
  datapoint_json = {:properties=>{}}
  building_json = {:properties=>building}
  # region_json = {:properties=>{:weather_file_name => "USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw", :climate_zone => "3C"}}
  region_json = {:properties=>{:weather_file_name => "USA_CO_Denver.Intl.AP.725650_TMY3.epw", :climate_zone => "5B"}}

  name = building[:name]

  # load the workflows
  baseline_osw = nil
  File.open(File.join(File.dirname(__FILE__), "/workflows/testing_baseline.osw"), 'r') do |f|
    baseline_osw = JSON::parse(f.read, :symbolize_names => true)
  end
  
  if run_retrofit
    # easier than deep cloning baseline_osw
    retrofit_osw = nil
    File.open(File.join(File.dirname(__FILE__), "/workflows/testing_baseline.osw"), 'r') do |f|
      retrofit_osw = JSON::parse(f.read, :symbolize_names => true) # easier than deep cloning
    end
  end
  
  # configure the osws with jsons
  baseline_osw = configure(baseline_osw, datapoint_json, building_json, region_json, true)
  if run_retrofit
    retrofit_osw = configure(retrofit_osw, datapoint_json, building_json, region_json, false)
  end

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
    f << JSON.pretty_generate(baseline_osw)
  end
    
  if run_retrofit
    retrofit_osw_path = "#{retrofit_osw_dir}/in.osw"
    File.open(retrofit_osw_path, 'w') do |f|
      f << JSON.pretty_generate(retrofit_osw)
    end
  end
    
  # run them
  run_script = File.join(File.dirname(__FILE__), "run.rb")

  jobs << "'#{openstudio_exe}' run -w '#{baseline_osw_path}'"

  if run_retrofit
    jobs << "'#{openstudio_exe}' run -w '#{retrofit_osw_path}'"
  end
end

# run the jobs
Parallel.each(jobs, in_threads: num_parallel) do |job|
  puts job
  system(job)
end