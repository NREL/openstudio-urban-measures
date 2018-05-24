# usage: add_measure_definitions.rb /path/to/workflow.osw

require_relative 'config'

require 'json'
require 'open3'
require 'pathname'

# read in OSW
workflow = nil
File.open(ARGV[0], 'r') do |file|
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
  
  return result
end

workflow[:steps].each do |step|
  measure_dir_name = step[:measure_dir_name]

  puts "scanning measure '#{measure_dir_name}' for args"
  
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
File.open(ARGV[0] + '.out', 'w') do |file|
  file << JSON::pretty_generate(workflow)
end



