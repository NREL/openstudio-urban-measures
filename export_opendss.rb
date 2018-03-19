# usage: export_openddss.rb /path/to/scenario.geojson /path/to/mapping.csv

require 'json'
require 'csv'
require 'fileutils'

def find_timestep(scenario)
  scenario[:features].each do |feature|
    if feature[:properties] && feature[:properties][:datapoint]
      datapoint = feature[:properties][:datapoint]
      if datapoint[:results] && datapoint[:results][:timesteps_per_hour]
        return 60 / datapoint[:results][:timesteps_per_hour]
      end
    end
  end
end

def find_feature(scenario, urbanopt_name)
  scenario[:features].each do |feature|
    if feature[:properties] && feature[:properties][:name]
      if feature[:properties][:name] == urbanopt_name
        return feature
      end
    end
  end
  return nil
end

def find_datapoint_id(scenario, urbanopt_name)
  feature = find_feature(scenario, urbanopt_name)
  if feature && feature[:properties] && feature[:properties][:datapoint]
    return feature[:properties][:datapoint][:id]
  end
  return nil
end

def find_real_reactive_factions(scenario, urbanopt_name)
  # todo
  return [0.95, 0.05]
end

def get_timeseries(datapoint_id, run_dir, timeseries, timestep)
  result = []
  header = nil
  index = nil
  j_to_kw = 1.0 / (timestep * 60.0 * 1000.0)
  filename = File.join(run_dir, "datapoint_#{datapoint_id}", 'reports', 'datapoint_reports_report.csv')
  CSV.foreach(filename) do |row|
    if header.nil?
      header = row
      index = header.find_index(timeseries)
    else
      if index
        result << row[index].to_f * j_to_kw
      else
        result << 0
      end
    end
  end
  return result
end

scenario_filename = ARGV[0]
mapping_filename = ARGV[1]

if !File.exist?(scenario_filename) || !File.exist?(mapping_filename)
  puts 'usage: export_openddss.rb /path/to/scenario.geojson /path/to/mapping.csv'
  exit(1)
end

run_dir = File.dirname(scenario_filename)
export_dir = File.join(run_dir, 'OpenDSS', File.basename(scenario_filename, '.*') + '/')

if File.exist?(export_dir)
  FileUtils.rm_rf(export_dir)
end
FileUtils.mkdir_p(export_dir)

scenario = nil
File.open(scenario_filename, 'r') do |file|
  scenario = JSON.parse(file.read, symbolize_names: true)
end

loads = {}
header = nil
CSV.foreach(mapping_filename) do |row|
  if header.nil?
    header = row
    next
  end

  urbanopt_name = row[0]
  timeseries = row[1]
  fraction = row[2]
  opendss_load_name = row[3]
  opendss_real_power_filename = row[4]
  opendss_reactive_power_filename = row[5]

  if loads[opendss_load_name].nil?
    loads[opendss_load_name] = []
  end

  break if row[0].nil?
  puts row
  loads[opendss_load_name] << {
    urbanopt_name: row[0].strip,
    timeseries: row[1].strip,
    fraction: row[2].strip,
    opendss_load_name: row[3].strip,
    opendss_real_power_filename: row[4].strip,
    opendss_reactive_power_filename: row[5].strip
  }
end

# simulation timestep in minutes
timestep = find_timestep(scenario)

loads.each_value do |load|
  real_load_sum = []
  reactive_load_sum = []
  load.each do |entry|
    datapoint_id = find_datapoint_id(scenario, entry[:urbanopt_name])
    real_reactive_factions = find_real_reactive_factions(scenario, entry[:urbanopt_name])
    timeseries = get_timeseries(datapoint_id, run_dir, entry[:timeseries], timestep)

    timeseries.each_index do |i|
      real_load_sum[i] = 0 if real_load_sum[i].nil?
      reactive_load_sum[i] = 0 if reactive_load_sum[i].nil?

      real_load_sum[i] += real_reactive_factions[0] * timeseries[i]
      reactive_load_sum[i] += real_reactive_factions[1] * timeseries[i]
    end
  end

  # for some reason NREL campus loads have extra hour of data
  real_load_sum[real_load_sum.size] = real_load_sum[real_load_sum.size - 1]
  reactive_load_sum[reactive_load_sum.size] = reactive_load_sum[reactive_load_sum.size - 1]

  File.open(File.join(export_dir, load[0][:opendss_real_power_filename]), 'w') do |file|
    file << real_load_sum.join("\n")
  end

  File.open(File.join(export_dir, load[0][:opendss_reactive_power_filename]), 'w') do |file|
    file << reactive_load_sum.join("\n")
  end
end
