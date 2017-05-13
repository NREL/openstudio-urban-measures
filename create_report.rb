require 'json'
require 'erb'
require 'csv'

project_name = ARGV[0]
project_path = "#{File.dirname(__FILE__)}/run/#{project_name}/"

if project_name.nil? || project_name.empty?
  puts "Missing required argument project name"
  exit
elsif !File.exists?(project_path)
  puts "Cannot find project '#{project_name}'"
  exit
end

scenarios = []
Dir.glob(project_path + "*_timeseries.csv").each do |scenario_path|
  scenario = {}
  
  md = /(.*)_timeseries.csv/.match(File.basename(scenario_path))
  scenario_name = md[1]
  scenario[:name] = scenario_name

  i = 0
  timestep_per_hr = 4
  num_rows = 8760*timestep_per_hr
  headers = []
  annual_values = {}
  timestep_values = {}
  daily_values = {}
  monthly_values = {}
  CSV.foreach(scenario_path) do |row|
    if i == 0
      # header row
      headers = row
      headers.each do |header|
        annual_values[header] = 0
        timestep_values[header] = []
        daily_values[header] = []
      end
    elsif i <= num_rows
      headers.each_index do |j|
        annual_values[headers[j]] += row[j].to_f
        timestep_values[headers[j]] << row[j].to_f 
      end
    end
    i += 1
  end
  
  headers.each_index do |j|
  
    daily_sums = []
    all_values = timestep_values[headers[j]]
    
    raise "Wrong size #{all_values.size} != #{num_rows}" if all_values.size != num_rows
    
    i = 1
    day_sum = 0
    all_values.each do |v|
      day_sum += v
      if i == 24*timestep_per_hr
        daily_sums << day_sum
        i = 1
      else
        i += 1
      end
    end
    
    raise "Wrong size #{daily_sums.size} != 365" if daily_sums.size != 365
    
    daily_values[headers[j]] = daily_sums
    
    # horrendous
    monthly_sums = []
    days_per_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    k = 0
    monthly_sum = 0
    days_per_month.each do |days|
      (1..days).each do |day|
        monthly_sum += daily_sums[k]
        k += 1
      end
      
      monthly_sums << monthly_sum
    end
    
    raise "Wrong size #{k} != 365" if k != 365
    
    monthly_values[headers[j]] = monthly_sums
  end

  scenario[:annual_values] = annual_values
  #scenario[:timestep_values] = timestep_values
  scenario[:daily_values] = daily_values
  scenario[:monthly_values] = monthly_values
  
  scenarios << scenario
end


# read in template
html_in_path = "#{File.dirname(__FILE__)}/reports/scenario_comparison.html.in"
html_in = ""
File.open(html_in_path, 'r') do |file|
  html_in = file.read
end
    
# configure template with variable values
os_data = "var scenarios = #{JSON::generate(scenarios)};\nsetReportDir(\"#{project_path}\");\nsetData(scenarios);"
renderer = ERB.new(html_in)
html_out = renderer.result(binding)

# write html file
html_out_path = "#{project_path}/scenario_comparison.html"
File.open(html_out_path, 'w') do |file|
  file << html_out
  
  # make sure data is written to the disk one way or the other      
  begin
    file.fsync
  rescue
    file.flush
  end
end