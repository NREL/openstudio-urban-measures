# script that runs an osw, alternative to CLI, used only because CLI does not have ability to load OpenSSL
# ruby run.rb openstudio_rb_dir osw_path

require_relative 'config'
require 'logger'

openstudio_rb_dir = ARGV[0]
openstudio_bin_dir = File.join(ARGV[0], '../bin/')
$:.unshift(openstudio_rb_dir)
if /win/.match(RUBY_PLATFORM) or /mingw/.match(RUBY_PLATFORM)
  ENV['PATH'] = openstudio_rb_dir + ";" + openstudio_bin_dir + ";" + ENV['PATH']
else
  ENV['PATH'] = openstudio_rb_dir + ":" + openstudio_bin_dir + ":" + ENV['PATH']
end

require 'openstudio'
require 'openstudio-workflow'
require 'openstudio/workflow/adapters/output_adapter'

$logger = Logger.new(STDOUT)
$logger.level = Logger::ERROR
#$logger.level = Logger::WARN
#$logger.level = Logger::DEBUG

OpenStudio::Logger.instance.standardOutLogger.enable
OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Error)
#OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Warn)
#OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Debug)

debug = true
puts "ARGV[1] = #{ARGV[1]}"
osw_path = ARGV[1]
osw_dir = File.dirname(osw_path)

# Run workflow.osw
run_options = Hash.new
run_options[:debug] = debug
run_options[:preserve_run_dir] = true # because we are running in .

# do the run
k = OpenStudio::Workflow::Run.new(osw_path, run_options)
final_state = k.run