require 'json'
require 'csv'
require 'fileutils'

# Gems required for geographic queries
require 'ffi'
# Make sure that the OSGeo binaries are found
ENV['GEOS_LIBRARY_PATH'] = 'C:\OSGeo4W64\bin'
require 'ffi-geos'
require 'rgeo'
require 'rgeo/geo_json'

# Check that the correct libraries are installed
unless RGeo::Geos.supported?
  @logs << "Need to install OSGeo4W package."
  @logs << "On Windows, follow these instructions: https://stackoverflow.com/questions/22297117/rgeo-on-ruby-under-windows-how-to-enable-geos-support"
  exit
end

factory = RGeo::Geos.factory(:native_interface => :ffi)

# Save the output to a log file
@logs = []

# Specify the location of the files
# TODO include the site features in the scenario geojson for things like extracting PV
scenario_filename = 'C:/GitRepos/openstudio-urban-measures/run/Pena Station/NREL ZNE Ready 2017.geojson'
geojson_with_site_features_filename = 'C:/Projects/Pena Station/UrbanOpt/geojson files/site_and_blocks_revised.json'
transformer_csv_filename = 'C:/Projects/Pena Station/UrbanOpt/transformer data/transformers.csv'

def find_timestep(scenario)
  scenario.each do |feature|
    datapoint = feature.property('datapoint')
    if datapoint['results'] && datapoint['results']['timesteps_per_hour']
      return 60 / datapoint['results']['timesteps_per_hour']
    end
  end
end

def find_feature(scenario, urbanopt_name)
  scenario.each do |feature|
    if feature.property('name') == urbanopt_name
      return feature
    end
  end
  return nil
end

def find_datapoint_id(scenario, urbanopt_name)
  feature = find_feature(scenario, urbanopt_name)
  if feature
    return feature.property('datapoint')['id']
  end
  return nil
end

def find_real_reactive_factions(scenario, urbanopt_name)
  # todo
  return [0.95, 0.05]
end

def get_timeseries(datapoint_id, run_dir, timeseries)
  result = []
  header = nil
  index = nil
  
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
        result << row[index].to_f
      else
        result << 0
      end
    end
  end
  return result
end

# Gets the urbanopt-based area for the building footprint
def building_footprint_area(feature)
  # Get the area and number of stories
  # and calculate the footprint area.
  area_ft2 = feature.property('floor_area').to_f
  # @logs << "#{feature.property('name')} is #{area_ft2}"
  stories = feature.property('number_of_stories').to_f
  footprint_area_ft2 = area_ft2 / stories
  return footprint_area_ft2
end

# Gets the 
# @param kv [Double] the kv rating of the tranformer (0.208, 0.24, 0.48)
# @param peak_kw [Double] the peak kW to handle
# @param safety_factor [Double] multiply the peak kW by this before selection
# @return [Hash] a has with keys:  name, capacity_kva, pct_impedence,
#   cost, num_phases, reactance, high_side_resistance, low_side_resistance
def get_transformer(transformer_data, kv, peak_kw, safety_factor)
  # Calculate the design kW
  dsn_kw = peak_kw * (1.0 + safety_factor)
  # loop through all transformers
  sel_trans = nil
  transformer_data.each do |trans|
    # Skip transformers that don't match the kV rating
    next unless trans[:kv].to_f == kv
    # Skip to the next size up if the design kW
    # is bigger than the rated kVA.
    next unless trans[:capacity_kva] > dsn_kw
    # If here, we have found a suitable tranformer
    sel_trans
    @logs << "-   For #{kv}kv, #{dsn_kw.round}kW with safety factor, selected #{trans[:name]} with a design capacity of #{trans[:capacity_kva]}kVA."
    return trans
  end

  # Warn if nothing could be found
  if sel_trans.nil?
    @logs << "ERROR - Could not find a transformer for #{kv}kv, #{dsn_kw.round}kW with safety factor"
  end

  return {}
  
end

# Verify the scenario
if !File.exists?(scenario_filename)
  @logs << "Could not find the scenario file #{scenario_filename}"
  exit
end

# Verify the site JSON
# TODO remove once scenario geojson has taxlot features
if !File.exists?(geojson_with_site_features_filename)
  @logs << "Could not find the full site geojson file #{geojson_with_site_features_filename}"
  exit
end

# Verify the transformer data
if !File.exists?(transformer_csv_filename)
  @logs << "Could not find the transformer data file #{transformer_csv_filename}"
  exit
end

# Load the scenario
scenario = nil
File.open(scenario_filename, 'r') do |file|
  scenario = RGeo::GeoJSON.decode(file.read, json_parser: :json)
end

# Verify and load the site geojson
site_json = nil
File.open(geojson_with_site_features_filename, 'r') do |file|
  site_json = RGeo::GeoJSON.decode(file.read, json_parser: :json)
end

# Verify and load the transformer data
raw_transformer_data = CSV.table(transformer_csv_filename)
transformer_data = raw_transformer_data.map { |row| row.to_hash }
@logs << "*** Transformer Library ***"
@logs << transformer_data
@logs << ''

# Extract the scenario name from the file name
scenario_name = File.basename(scenario_filename).gsub('.geojson','')

# Make a directory to save the exports
run_dir = File.dirname(scenario_filename)
export_dir = File.join(run_dir, scenario_name, 'OpenDSS')
Dir.mkdir(export_dir) unless Dir.exist?(export_dir)
@logs << "Exporting OpenDSS files to #{export_dir}"

# Remove special characters from scenarion name for use
scenario_name = scenario_name.gsub(/\W/,'_')

# Simulation timestep in minutes
timestep = find_timestep(scenario)
num_intervals = 35040 # will be updated based on timeseries data
min_per_interval = 15

# Conversion factors
j_to_kw = 1.0 / (timestep*60.0*1000.0)
ft2_to_acres = 1.0 / 43560.0 # 43560 ft2/acre

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

# Irradiance - one per scenario, CSV file exported inside buildings loop
loadshapes << "! Irradiance profile for the area"
loadshapes << "New LoadShape.irrad Npts=#{num_intervals} minterval=#{min_per_interval} mult=(file=irradiance.csv) Action=normalize"

# Temperature - one per scenario, CSV file exported inside buildings loop    
loadshapes << "! Temperature profile for the area"
loadshapes << "New Tshape.outdoor_air_temp npts=#{num_intervals} minterval=#{min_per_interval} temp=(file=outdoor_air_temperature.csv)"
loadshapes << "! Loadshapes for the buildings"
    
# Stubs of other files which users will need to populate manually
linecodes << "! Define your line types"
lines << "! Define your lines"
generators << "! Define your generators"

# Create OpenDSS objects for each building
loads << "! Loads for the buildings"
storages << "! Storage for the buildings"
pv_systems << "! PV systems for the buildings"
bus_coordinates << "! Bus coordinates for the buildings"
transformers << "! Transformers for the buildings"
irradiance_exported = false
temperature_exported = false
total_footprint_area_ft2 = 0.0
total_bldg_area_ft2 = 0.0
total_num_buildings = 0
total_bldg_pv_kw = 0.0
total_bldg_pv_area_ft2 = 0.0
max_irrad_kw_per_m2 = nil
total_bldg_transformer_cap_kva = 0.0
total_pv_transformer_cap_kva = 0.0
scenario.each do |feature|
  # next
  # Skip non-buildings
  next unless feature.property('type') == 'Building'
  total_num_buildings += 1
  
  # Get the name, modified for OpenDSS
  name = feature.property('name').gsub(/\W/,'_')
  @logs << ''
  @logs << name
  
  # Get the area
  bldg_area_ft2 = feature.property('floor_area').to_f
  total_bldg_area_ft2 += bldg_area_ft2
  footprint_area_ft2 = building_footprint_area(feature)
  total_footprint_area_ft2 += footprint_area_ft2

  # Load profiles
  real_power_filename = "#{name}_P"
  reactive_power_filename = "#{name}_Q"
  
  datapoint_id = find_datapoint_id(scenario, feature.property('name'))
  real_reactive_factions = find_real_reactive_factions(scenario, feature.property('name'))
  apparent_power_j = get_timeseries(datapoint_id, run_dir, 'Electricity:Facility')

  # Export load profiles if data for the loads exists.
  # May not exist if simulations failed.
  peak_building_kw = nil
  if apparent_power_j
    apparent_power = apparent_power_j.collect { |n| n * j_to_kw }
    num_intervals = apparent_power.size

    # Convert to Real and Reactive power
    power_factor = 0.95
    real_power = apparent_power.collect { |n| n * power_factor }
    reactive_power = apparent_power.collect { |n| n * (1 - power_factor) }
    
    # Get the peak load for transformer selection
    peak_building_kw = real_power.max
    
    # Write out real power CSV
    File.open("#{export_dir}/#{real_power_filename}.csv", 'w') do |file|
      file << real_power.join("\n")
    end

    # Write out reactive power CSV
    File.open("#{export_dir}/#{reactive_power_filename}.csv", 'w') do |file|
      file << reactive_power.join("\n")
    end

  else
    @logs << "No load profile data available for #{name}; simulation may have failed"
  end

  # Loadshapes
  loadshapes << "New LoadShape.#{name} Npts=#{num_intervals} minterval=#{min_per_interval} Pmult=(file=#{real_power_filename}.csv) Qmult=(File=#{reactive_power_filename}.csv) UseActual=yes"
  
  # Loads
  kv = 0.48 # .208, .48 (208V or 480V) # TODO use 208 for Res, 480 for Com
  loads << "New Load.#{name} Bus1=low_#{name} kV=#{kv} Yearly=#{name}"

  # Storage (batteries)
  phases = 3 # 1, 2, 3 phase
  kw = 0 # rated kW of the battery
  kwh = 0 # rated kWh of the battery
  conn = 'delta' # delta, wye
  disp_mode = 'default' # default, follow, load level, price
  storages << "New Storage.bat_#{name} phases=#{phases} bus1=low_#{name} kv=#{kv} kWRated=#{kw} kWhRated=#{kwh} Conn=#{conn} DispMode=#{disp_mode} Yearly=#{name}" 

  # Irradiance profile (kW/m^2) - only export this once per scenario
  # this assumes a uniform profile across the entire site
  
  unless irradiance_exported
    irrad_w_per_m2 = get_timeseries(datapoint_id, run_dir, 'Site Direct Solar Radiation Rate per Area')
    if irrad_w_per_m2.inject(0){|sum,x| sum + x } > 0 # total of zero means no data was found
      # Convert to kW/m^2
      irrad_kw_per_m2 = irrad_w_per_m2.collect { |n| n / 1000 }
      max_irrad_kw_per_m2 = irrad_kw_per_m2.max
      @logs << "Getting irradiance data from #{name} simulation."
      # Write out irradiance CSV
      File.open("#{export_dir}/irradiance.csv", 'w') do |file|
        file << irrad_kw_per_m2.join("\n")
      end
      irradiance_exported = true
    end
  end

  # Temperature profile (C) - only export this once per scenario
  # this assumes a uniform profile across the entire site
  unless temperature_exported
    temperature = get_timeseries(datapoint_id, run_dir, 'Site Outdoor Air Drybulb Temperature')
    if temperature.inject(0){|sum,x| sum + x } > 0 # total of zero means no data was found
      @logs << "Getting temperature data from #{name} simulation."
      # Write out temperature CSV
      File.open("#{export_dir}/outdoor_air_temperature.csv", 'w') do |file|
        file << temperature.join("\n")
      end
      temperature_exported = true
    end
  end
  
  # PV
  frac_footprint_usable_for_pv = 0.5 # fraction of building footprint that can be covered by pv
  pv_w_per_ft2 = 18.0 # assumption of pv production per ft2 of roof area covered
  area_pv_ft2 = footprint_area_ft2 * frac_footprint_usable_for_pv
  total_bldg_pv_area_ft2 += area_pv_ft2
  kw_pv = (area_pv_ft2 * pv_w_per_ft2 / 1000).round
  pmpp_pv = kw_pv # nominal peak power
  total_bldg_pv_kw += kw_pv
  kva_pv = pmpp_pv
  @logs << "#{name} has #{kw_pv} kW of PV based on #{area_pv_ft2.round} ft2 of rooftop area"
  pv_systems << "New PVSystem.pv_#{name} phases=#{phases} bus1=low_#{name} kv=#{kv} kVA=#{kva_pv} Pmpp=#{pmpp_pv} Daily=irrad Tyearly=outdoor_air_temp Irradiance=#{max_irrad_kw_per_m2}"

  # Building coordinates based on the centroid of the building
  bus_coordinates << "low_#{name} #{feature.geometry.centroid.x} #{feature.geometry.centroid.y}"
  bus_coordinates << "high_#{name} #{feature.geometry.centroid.x} #{feature.geometry.centroid.y}"
  
  # Transformer for the building
  safety_factor = 0.25
  trans_conn = 'wye' # delta, wye
  high_side_kv = 13.2
  low_side_kv = 0.48
  if peak_building_kw
    trans = get_transformer(transformer_data, low_side_kv, peak_building_kw, safety_factor)
    trans_cap_kva = trans[:capacity_kva]
    total_bldg_transformer_cap_kva += trans_cap_kva.to_f
    high_side_resistance = trans[:high_side_resistance]
    low_side_resistance = trans[:low_side_resistance]
    trans_reactance = trans[:reactance]
    transformers << "New Transformer.t_#{name} Buses=[high_#{name} low_#{name}] Conns=[#{trans_conn} #{trans_conn}] kVs=[#{high_side_kv} #{low_side_kv}] kVA=[#{trans_cap_kva} #{trans_cap_kva}] %R=[#{high_side_resistance} #{low_side_resistance}] XHL=#{trans_reactance}"
  else
    @logs << "ERROR for #{name}, there was no building peak kW, cannot add transformer for this building."
  end
    
end

# Create OpenDSS objects for each lot
@logs << ''
@logs << 'Making OpenDSS objects for site'
total_site_area_ft2 = 0.0
total_num_sites = 0
total_site_pv_area_ft2 = 0.0
total_site_pv_kw = 0.0
if site_json
  loads << "! Loads for the lots"
  storages << "! Storage for the lots"
  pv_systems << "! PV systems for the lots"
  bus_coordinates << "! Bus coordinates for the lots"
  transformers << "! Transformers for the lots (PV and storage)"
  site_json.each do |feature|
    # Skip non-taxlots
    next unless feature.property('type') == 'Taxlot'
    total_num_sites += 1
    
    # Get the name
    name = feature.property('name').gsub(/\W/,'_')
    @logs << ''
    @logs << name
    
    # Get the area of the lot using the geometry methods
    area_unknown = feature.geometry.area # TODO figure out units
    ft2_per_unknown = 112514477418 # conversion factor from comparing 
    area_ft2 = area_unknown * ft2_per_unknown
    area_acres = area_ft2 * ft2_to_acres
    @logs << "#{name} is #{area_unknown} unknown units aka #{area_ft2.round} ft2 aka #{area_acres.round(1)} acres."
    total_site_area_ft2 += area_ft2
    # next
    
    # Extract the block number from the name
    # (Pena Station specific)
    block = nil 
    m = name.match(/Block (\S*)/)
    if m
      block = m[1]
      @logs << "#{block} holds #{name}"
    end
    
    # Find the area of the buildings on the lot
    lot_geometry = feature.geometry
    area_of_bldgs_ft2 = 0.0
    scenario.each do |bldg|
      next unless bldg.property('type') == 'Building'
      if lot_geometry.intersects?(bldg.geometry)
        # Get the area 
        footprint_area_ft2 = building_footprint_area(bldg)
        # @logs << "    #{bldg.property('name')} is #{footprint_area_ft2} ft2"
        area_of_bldgs_ft2 += footprint_area_ft2
      end
    end
    @logs << "#{name} has #{area_of_bldgs_ft2.round} ft2 of buildings on lot"

    # Storage (batteries)
    phases = 3 # 1, 2, 3 phase
    kv = 0.48 # .208, .48 (208V or 480V)
    kw = 0 # rated kW of the battery
    kwh = 0 # rated kWh of the battery
    conn = 'delta' # delta, wye
    disp_mode = 'default' # default, follow, load level, price
    storages << "New Storage.bat_site_#{name} phases=#{phases} bus1=low_#{name} kv=#{kv} kWRated=#{kw} kWhRated=#{kwh} Conn=#{conn} DispMode=#{disp_mode} Yearly=#{name}" 

    # PV
    # fraction of site footprint that can be covered by pv
    # Assuming 40% instead of 50% to account for right-of-way and sidewalk
    frac_footprint_usable_for_pv = 0.4 
    mw_per_acre = 0.2 # 4-6 Acres/MW is typical for ground-mounted PV per Shanti
    area_pv_ft2 = (area_ft2 - area_of_bldgs_ft2) * frac_footprint_usable_for_pv
    total_site_pv_area_ft2 += area_pv_ft2
    area_pv_acres = (area_pv_ft2 * ft2_to_acres).round(1)
    kw_pv = area_pv_acres * mw_per_acre * 1000
    pmpp_pv = kw_pv # nominal peak power
    total_site_pv_kw += kw_pv
    kva_pv = pmpp_pv
    @logs << "#{name} has #{kw_pv} kW of PV based on #{area_pv_acres} acres of site PV area assuming #{(frac_footprint_usable_for_pv*100).round}% coverage of non-building footprint."
    pv_systems << "New PVSystem.pv_site_#{name} phases=#{phases} bus1=low_#{name} kv=#{kv} kVA=#{kva_pv} Pmpp=#{pmpp_pv} Yearly=irrad Tyearly=outdoor_air_temp Irradiance=#{max_irrad_kw_per_m2}"

    # PV coordinates based on the centroid of the lot
    bus_coordinates << "low_#{name} #{feature.geometry.centroid.x} #{feature.geometry.centroid.y}"
    bus_coordinates << "high_#{name} #{feature.geometry.centroid.x} #{feature.geometry.centroid.y}"

    # Transformer for the PV
    trans_conn = 'wye' # delta, wye
    safety_factor = 0.25
    high_side_kv = 13.2
    low_side_kv = 0.48
    trans = get_transformer(transformer_data, low_side_kv, kw_pv, safety_factor)
    trans_cap_kva = trans[:capacity_kva]
    total_pv_transformer_cap_kva += trans_cap_kva.to_f
    high_side_resistance = trans[:high_side_resistance]
    low_side_resistance = trans[:low_side_resistance]
    trans_reactance = trans[:reactance]
    transformers << "New Transformer.t_#{name} Buses=[high_#{name} low_#{name}] Conns=[#{trans_conn} #{trans_conn}] kVs=[#{high_side_kv} #{low_side_kv}] kVA=[#{trans_cap_kva} #{trans_cap_kva}] %R=[#{high_side_resistance} #{low_side_resistance}] XHL=#{trans_reactance}"

    # Get the centroid of the lot
    centroid_lot = feature.geometry.centroid
 
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

Set VoltageBases=[13.2, 0.48]

! Settings
Set Casename=#{scenario_name}
Set Demandinterval=true
Set DIVerbose=true
Set Mode=yearly
Set Stepsize=1m
Set Number=#{num_intervals}
Set Maxiterations=1000
Set Maxcontroliter=1000
Set Overloadreport=yes
Set Voltexcept=true

! Load Flow
calcv
Solve
closedi
"
]

# Ensure that the irradiance and temperature were exported
@logs << "ERROR - irradiance profile was not exported because data was not found in any simulation" unless irradiance_exported
@logs << "ERROR - temperature profile was not exported because data was not found in any simulation" unless temperature_exported

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

# Summarize the information
@logs << ''
@logs << '***Summary***'
total_site_area_acres = (total_site_area_ft2 * ft2_to_acres).round
total_site_pv_area_acres = (total_site_pv_area_ft2 * ft2_to_acres).round
total_footprint_area_acres = (total_footprint_area_ft2 * ft2_to_acres).round
total_bldg_area_acres = (total_bldg_area_ft2 * ft2_to_acres).round
total_bldg_pv_area_acres = (total_bldg_pv_area_ft2 * ft2_to_acres).round

total_site_pv_mw = (total_site_pv_kw / 1000)
total_bldg_pv_mw = (total_bldg_pv_kw / 1000)

@logs << "The site has #{total_num_sites} lots with an area of #{total_site_area_ft2.round} ft2 aka #{total_site_area_acres} acres."
@logs << "The site has #{total_num_buildings} buildings with a footprint area of #{total_footprint_area_ft2} ft2 aka #{total_footprint_area_acres} acres."
@logs << "The site has #{total_num_buildings} buildings with a floor area of #{total_bldg_area_ft2} ft2."

@logs << "The site has #{total_site_pv_mw} MW of canopy or ground-mounted PV with an area of #{total_site_pv_area_ft2} ft2 aka #{total_site_pv_area_acres} acres.  This is #{(total_site_pv_area_acres.to_f/total_site_pv_mw.to_f).round(1)} acres/MW."
@logs << "The site has #{total_bldg_pv_mw} MW of roof-mounted PV with an area of #{total_bldg_pv_area_ft2} ft2 aka #{total_bldg_pv_area_acres} acres.  This is #{(total_bldg_pv_kw*1000/total_bldg_pv_area_ft2).round(1)} W/ft2."

@logs << "The site needs #{total_bldg_transformer_cap_kva.round} kVA of transformers for buildings (sized for buildings, not PV on rooftop."
@logs << "The site needs #{total_pv_transformer_cap_kva.round} kVA of transformers for canopy or ground-mounted PV."

File.open("#{export_dir}/opendss_export.log", 'w') do |file|
  @logs.each do |msg|
    file.puts msg
  end
end

