# this example runs without using the web interface to query input data

require 'json'
require 'parallel'
require 'fileutils'

include = ""
#openstudio_2_0 = "E:/openstudio-2-0/build"
#include = "-I '#{File.join(openstudio_2_0, 'OSCore-prefix/src/OSCore-build/ruby/Debug/')}"

run_retrofit = true
num_parallel = 7

buildings = [
  {name: "Large-Office",             space_type: "Office",                        floor_area: 46320,  number_of_stories: 12, window_to_wall_ratio: 0.4 },
  {name: "Medium-Office",            space_type: "Office",                        floor_area: 4982,   number_of_stories: 3,  window_to_wall_ratio: 0.3 },
  {name: "Small-Office",             space_type: "Office",                        floor_area: 511,    number_of_stories: 1,  window_to_wall_ratio: 0.2 },
  {name: "Warehouse",                space_type: "Nonrefrigerated warehouse",     floor_area: 4835,   number_of_stories: 1,  window_to_wall_ratio: 0.01},
  {name: "Stand-alone Retail",       space_type: "Retail other than mall",        floor_area: 2319,   number_of_stories: 1,  window_to_wall_ratio: 0.07},
  {name: "Strip-Mall",               space_type: "Strip shopping mall",           floor_area: 2090,   number_of_stories: 1,  window_to_wall_ratio: 0.1 },
  {name: "Primary-School",           space_type: "Education",                     floor_area: 6871,   number_of_stories: 1,  window_to_wall_ratio: 0.35},
  {name: "Secondary-School",         space_type: "Education",                     floor_area: 19592,  number_of_stories: 2,  window_to_wall_ratio: 0.33},
  {name: "Supermarket",              space_type: "Food sales",                    floor_area: 4180,   number_of_stories: 1,  window_to_wall_ratio: 0.1 },
  {name: "Quick-Service-Restaurant", space_type: "Food service",                  floor_area: 232,    number_of_stories: 1,  window_to_wall_ratio: 0.14},
  {name: "Full-Service-Restaurant",  space_type: "Food service",                  floor_area: 511,    number_of_stories: 1,  window_to_wall_ratio: 0.17},
  {name: "Hospital",                 space_type: "Inpatient health care",         floor_area: 22422,  number_of_stories: 5,  window_to_wall_ratio: 0.16},
  {name: "Outpatient-Health-Care",   space_type: "Outpatient health care",        floor_area: 3804,   number_of_stories: 3,  window_to_wall_ratio: 0.2 },
  {name: "Small-Hotel",              space_type: "Lodging",                       floor_area: 4013,   number_of_stories: 4,  window_to_wall_ratio: 0.1 },
  {name: "Large-Hotel",              space_type: "Lodging",                       floor_area: 11345,  number_of_stories: 6,  window_to_wall_ratio: 0.3 },
  {name: "Midrise-Apartment",        space_type: "Multifamily (5 or more units)", floor_area: 3134,   number_of_stories: 4,  window_to_wall_ratio: 0.2,  number_of_residential_units: 24},
  {name: "Single-Family",            space_type: "Single-Family",                 floor_area: 200,    number_of_stories: 2,  window_to_wall_ratio: 0.3,  number_of_residential_units: 1},
  {name: "Multifamily-4",            space_type: "Multifamily (2 to 4 units)",    floor_area: 800,    number_of_stories: 2,  window_to_wall_ratio: 0.3,  number_of_residential_units: 4},
  {name: "Multifamily-8",            space_type: "Multifamily (5 or more units)", floor_area: 1600,   number_of_stories: 3,  window_to_wall_ratio: 0.3,  number_of_residential_units: 8},
  {name: "Mobile-Home",              space_type: "Mobile Home",                   floor_area: 80,     number_of_stories: 1,  window_to_wall_ratio: 0.3,  number_of_residential_units: 1}
]

#buildings = [buildings[0]]
  
def merge(workflow, properties)
  workflow[:steps].each do |step|
    step[:arguments].each do |argument|
      name = argument[:name]
      if properties[name.to_sym]
        value = properties[name.to_sym]
        puts "Setting '#{name}' of '#{step[:measure_dir_name]}' to '#{value}'"
        argument[:value] = value
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