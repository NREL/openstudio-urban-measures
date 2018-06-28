# usage: add_measure_definitions.rb /path/to/workflow.osw

require_relative 'config'

require 'json'
require 'open3'
require 'pathname'

# read in OSW
workflow = nil
workflow_path = ARGV[0]
File.open(workflow_path, 'r') do |file|
  workflow = JSON::parse(file.read, :symbolize_names => true)
end

def get_measure_definition(measure_dir)
  result = nil
  command = "'#{UrbanOptConfig::OPENSTUDIO_EXE}' measure -a '#{measure_dir}'"
  Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
    # calling wait_thr.value blocks until command is complete
    if wait_thr.value.success?
      result =  JSON::parse(stdout.read, :symbolize_names => true)
      result.delete(:directory)
      result.delete(:measure_dir)
    end
  end

  # Check that the measure definition was created successfully
  if result.nil?
    # Nothing returned for this measure
    puts "ERROR getting measure definition for #{measure_dir}: No error message returned from measure manager"
  elsif result[:error]
    # Partial completion with error message
    puts "ERROR getting measure definition for #{measure_dir}: #{result[:error]}"
  end

  return result
end

# Add metadata for each measure in the workflow
workflow[:steps].each do |step|
  measure_dir_name = step[:measure_dir_name]
  
  definition = nil
  UrbanOptConfig::OPENSTUDIO_MEASURES.each do |dir|
    measure_dir = nil
    if Pathname.new(dir).absolute?
      measure_dir = File.join(dir, measure_dir_name)
    else
      measure_dir = File.join(File.absolute_path(dir, './run/scenario/datapoint/'), measure_dir_name)
    end
    
    if File.exists?(measure_dir) 
      definition = get_measure_definition(measure_dir)
      break
    end
  end
  
  if definition
    definition[:visible] = true
    definition[:arguments].each do |argument|
      argument[:visible] = true
    end
    step[:measure_definition] = definition
  end
end

# write modified workflow
File.open(workflow_path + '.out', 'w') do |file|
  file << JSON::pretty_generate(workflow)
end



