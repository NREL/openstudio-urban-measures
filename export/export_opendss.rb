require 'json'
require 'csv'
require 'fileutils'

# Specify the location of the files
scenario_filename = 'C:/GitRepos/openstudio-urban-measures/run/Pena Station/90.1-2013 Code Minimum.geojson'
# TODO include the site features in the scenario geojson for things like extracting PV
geojson_with_site_features_filename = 'C:\Projects\Pena Station\UrbanOpt\geojson files\site_and_blocks_revised.json'

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
  j_to_kw = 1.0 / (timestep*60.0*1000.0)
  filename = File.join(run_dir, "datapoint_#{datapoint_id}", "reports", "datapoint_reports_report.csv")
  unless File.exist?(filename)
    return nil
  end
  
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

# Verify and load the scenario
if !File.exists?(scenario_filename)
  puts "Could not find the scenario file #{scenario_filename}"
  exit
end

# Make a directory to save the exports
run_dir = File.dirname(scenario_filename)
export_dir = File.join(run_dir, "OpenDSS")
Dir.mkdir(export_dir) unless Dir.exist?(export_dir)
puts "Exporting OpenDSS files to #{export_dir}"

scenario = nil
File.open(scenario_filename, 'r') do |file|
  scenario = JSON::parse(file.read, :symbolize_names=>true)
end

# Verify and load the site geojson
site_json = nil
if !File.exists?(geojson_with_site_features_filename)
  puts "could not load the site geojson at #{geojson_with_site_features_filename}; cannot export site PV to OpenDSS."
else
  File.open(geojson_with_site_features_filename, 'r') do |file|
    site_json = JSON::parse(file.read, :symbolize_names=>true)
  end
end

# Extract the scenario name
scenario_name = File.basename(scenario_filename).gsub('.geojson','').gsub(/\W/,'_')

# Simulation timestep in minutes
timestep = find_timestep(scenario)
num_intervals = 8760 # will be updated based on timeseries data

# Arrays to store OpenDSS objects
loadshapes = []
loads = []
storages = []
pv_systems = []
bus_coordinates = []
linecodes = []
lines = []
generators = []
transformers = []

# Irradiance
# TODO irradiance profile
irrad_filename = 'irradiance'
loadshapes << "! Irradiance profile for the area"
loadshapes << "New LoadShape.irrad Npts=#{8760} minterval=#{1} mult=(file=#{irrad_filename}.csv) Action=normalized"

# Temperature
# TODO temperature profile
loadshapes << "! Temperature profile for the area"
loadshapes << "New Tshape.outdoor_air_temp npts=#{8760} interval=#{1} temp=(outdoor_air_temperature.csv file)"
loadshapes << "! Load profiles for the buildings"

# Stubs of other files which users will need to populate manually
linecodes << "! Define your line types"
lines << "! Define your lines"
generators << "! Define your generators"
transformers << "! Define your transformers"

# Create OpenDSS objects for each building
loads << "! Loads for the buildings"
storages << "! Storage for the buildings"
pv_systems << "! PV systems for the buildings"
bus_coordinates << "! Bus coordinates for the buildings"
lots_to_building_areas = {}
scenario[:features].each do |feature|
  props = feature[:properties]
  # Skip non-buildings
  next unless props[:type] == 'Building'
  
  # Get the name
  name = props[:name].gsub(/\W/,'_')
  
  # Get the area and number of stories
  # and calculate the footprint area.
  area_ft2 = props[:floor_area].to_f
  stories = props[:number_of_stories].to_f
  footprint_area_ft2 = area_ft2 / stories

  # Extract the block number from the name
  # (Pena Station specific)
  m = name.match(/Block (\S*)/)
  if m
    block = m[1]
    puts "#{block} holds #{name}"
    if lots_to_building_areas[block]
      lots_to_building_areas[block] += footprint_area_ft2
    else
      lots_to_building_areas[block] = footprint_area_ft2
    end
  end
  
  # Load profiles
  real_power_filename = "#{name}_P"
  reactive_power_filename = "#{name}_Q"
  
  datapoint_id = find_datapoint_id(scenario, props[:name])
  real_reactive_factions = find_real_reactive_factions(scenario, props[:name])
  apparent_power = get_timeseries(datapoint_id, run_dir, 'Electricity:Facility', timestep)
  
  # Export load profiles if data for the loads exists.
  # May not exist if simulations failed.
  if apparent_power
    num_intervals = apparent_power.size

    # Convert to Real and Reactive power
    power_factor = 0.95
    real_power = apparent_power.collect { |n| n * power_factor }
    reactive_power = apparent_power.collect { |n| n * (1 - power_factor) }
    
    # Write out real power CSV
    File.open("#{export_dir}/#{real_power_filename}.csv", 'w') do |file|
      file << real_power.join("\n")
    end

    # Write out reactive power CSV
    File.open("#{export_dir}/#{reactive_power_filename}.csv", 'w') do |file|
      file << reactive_power.join("\n")
    end

  else
    puts "No load profile data available for #{name}; simulation may have failed"
  end
  
  # Loadshapes
  loadshapes << "New LoadShape.#{name} Npts=#{num_intervals} minterval=#{1} Pmult=(file=#{real_power_filename}.csv) Qmult=(File=#{reactive_power_filename}.csv) UseActual=yes"
  
  # Loads
  kv = 0.48 # .208, .48 (208V or 480V)
  loads << "New Load.#{name} Bus1=bus_#{name} kV=#{kv} Daily=#{name}"

  # Storage (batteries)
  phases = 3 # 1, 2, 3 phase
  kw = 0 # rated kW of the battery
  kwh = 0 # rated kWh of the battery
  conn = 'delta' # delta, wye
  disp_mode = 'default' # default, follow, load level, price
  storages << "New Storage.bat_#{name} phases=#{phases} bus1=bus_#{name} kv=#{kv} kWRated=#{kw} kWhRated=#{kwh} Conn=#{conn} DispMode=#{disp_mode} Daily=#{name}" 
  
  # PV
  frac_footprint_usable_for_pv = 0.8 # fraction of building footprint that can be covered by pv
  pv_w_per_ft2 = 18.0 # assumption of pv production per ft2 of roof area covered
  pf_pv = 0.9 # power factor of the PV
  area_pv_ft2 = footprint_area_ft2 * frac_footprint_usable_for_pv
  kw_pv = (area_pv_ft2 * pv_w_per_ft2 / 1000).round
  kva_pv = kw_pv / pf_pv
  pmpp_pv = kw_pv # nominal peak power
  puts "#{name} has #{kw_pv} kW of PV based on #{area_pv_ft2.round} ft2 of rooftop area"
  pv_systems << "New PVSystem.pv_#{name} phases=#{phases} bus1=bus_#{name} kv=#{kw_pv} kVA=#{kva_pv} Pmpp=#{kw_pv} PF=#{pf_pv} Daily=irrad Tdaily=outdoor_air_temp"

  # Building coordinates
  # based on the centroid of the building
  bus_coordinates << "bus_#{name} #{feature[:centroid][0]} #{feature[:centroid][1]}"
  
end

# Create OpenDSS objects for each lot
puts ''
puts 'Making OpenDSS objects for site'
if site_json
  loads << "! Loads for the lots"
  storages << "! Storage for the lots"
  pv_systems << "! PV systems for the lots"
  bus_coordinates << "! Bus coordinates for the lots"
  site_json[:features].each do |feature|
    props = feature[:properties]
    # Skip non-taxlots
    next unless props[:type] == 'Taxlot'
    
    # Get the name
    name = props[:name].gsub(/\W/,'_')
    
    # Get the area of the lot
    area_ft2 = props[:footprint_area].to_f

    # Extract the block number from the name
    # (Pena Station specific)
    block = nil 
    m = name.match(/Block (\S*)/)
    if m
      block = m[1]
      puts "#{block} holds #{name}"
    end
    
    # Subtract the area of buildings on this lot, if any 
    area_of_bldgs_ft2 = 0
    if lots_to_building_areas[block]
      area_of_bldgs_ft2 = lots_to_building_areas[block]
    end
    
    # Loads
    kv = 0.48 # .208, .48 (208V or 480V)
    loads << "New Load.#{name} Bus1=bus_site_#{name} kV=#{kv} Daily=#{name}"

    # Storage (batteries)
    phases = 3 # 1, 2, 3 phase
    kw = 0 # rated kW of the battery
    kwh = 0 # rated kWh of the battery
    conn = 'delta' # delta, wye
    disp_mode = 'default' # default, follow, load level, price
    storages << "New Storage.bat_site_#{name} phases=#{phases} bus1=bus_#{name} kv=#{kv} kWRated=#{kw} kWhRated=#{kwh} Conn=#{conn} DispMode=#{disp_mode} Daily=#{name}" 

    # PV
    frac_footprint_usable_for_pv = 0.5 # fraction of site footprint that can be covered by pv
    pv_w_per_ft2 = 18.0 # assumption of pv production per ft2 of site area covered
    pf_pv = 0.9 # power factor of the PV
    area_pv_ft2 = (area_ft2 - area_of_bldgs_ft2) * frac_footprint_usable_for_pv
    kw_pv = (area_pv_ft2 * pv_w_per_ft2 / 1000).round
    kva_pv = kw_pv / pf_pv
    pmpp_pv = kw_pv # nominal peak power
    puts "#{name} has #{kw_pv} kW of PV based on #{area_pv_ft2.round} ft2 of site area at #{(frac_footprint_usable_for_pv*100).round}% coverage."
    pv_systems << "New PVSystem.pv_site_#{name} phases=#{phases} bus1=bus_#{name} kv=#{kw_pv} kVA=#{kva_pv} Pmpp=#{kw_pv} PF=#{pf_pv} Daily=irrad Tdaily=outdoor_air_temp"

    # Building coordinates
    # based on the centroid of the building
    # TODO need coordinates of lots for ground-mounted PV
    # bus_coordinates << "bus_site_#{name} #{feature[:centroid][0]} #{feature[:centroid][1]}"

  end
end

# Master file
base_kv = 13.2 # kV of connection
pu = 0.99
master = [
"Clear

New Circuit.#{scenario_name} BasekV=#{base_kv} Bus1=TODO_connection_to_utility pu=#{pu}

! Define the lines
Redirect linecodes.dss
Redirect lines.dss
Redirect generators.dss
Redirect transformers.dss

! Define the circuit elements
Redirect loadshapes.dss
Redirect loads.dss
Redirect storage.dss
Redirect pv_systems.dss
Redirect bus_coordinates.dss

New EnergyMeter.Feederhead Element=TODO_top_of_feeder Terminal=1 option=R PhaseVoltageReport=yes

Set VoltageBasis=[13.2, 0.48]

! Settings
Set Casename=#{scenario_name}
Set Demandinterval=true
Set DIVerbose=true
Set Mode=daily
Set Stepsize=1m
Set Number=#{num_intervals}
Set Maxiterations=1000
Set Maxcontroliter=1000
Set Overloadreport=yes
Set Voltexcept=true

Solve"
]

# Write out the .dss files
files = [
  [loadshapes, 'loadshapes'],
  [loads, 'loads'],
  [storages, 'storages'],
  [pv_systems, 'pv_systems'],
  [bus_coordinates, 'bus_coordinates'],
  [master, 'master'],
  [linecodes, 'linecodes'],
  [lines, 'lines'],
  [generators, 'generators'],
  [transformers, 'transformers']
]
files.each do |variable, filename|
  File.open("#{export_dir}/#{filename}.dss", 'w') do |file|
    variable.each do |object|
      file.puts object
    end
  end
end
