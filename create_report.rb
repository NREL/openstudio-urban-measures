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
  num_rows = 8760*4
  headers = []
  summary = {}
  values = {}
  CSV.foreach(scenario_path) do |row|
    if i == 0
      # header row
      headers = row
      headers.each do |header|
        summary[header] = 0
        values[header] = []
      end
    elsif i <= num_rows
      headers.each_index do |j|
        summary[headers[j]] += row[j].to_f
        values[headers[j]] << row[j].to_f
      end
    end
    i += 1
  end

  scenario[:summary] = summary
  #scenario[:values] = values
  
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