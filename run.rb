# script that runs an osw, alternative to CLI, used only because CLI does not have ability to load OpenSSL
# ruby run.rb openstudio_rb_dir osw_path

require_relative 'config'
require 'logger'

openstudio_rb_dir = ARGV[0]
openstudio_bin_dir = File.join(ARGV[0], '../bin/')
$:.unshift(openstudio_rb_dir)
if /win/.match(RUBY_PLATFORM) or /mingw/.match(RUBY_PLATFORM)
  ENV['PATH'] = openstudio_rb_dir + ";" + ENV['PATH']
else
  ENV['PATH'] = openstudio_rb_dir + ":" + ENV['PATH']
end

require 'openstudio'
require 'openstudio-workflow'
require 'openstudio/workflow/adapters/output_adapter'


# Log lever
$logger = Logger.new(STDOUT)
#$logger.level = Logger::ERROR
#$logger.level = Logger::WARN
$logger.level = Logger::DEBUG

OpenStudio::Logger.instance.standardOutLogger.enable
#OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Error)
OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Warn)
#OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Debug)

debug = true


# **START** 
# Set up all bundler paths to require appropriate gems (needed)
# Then blank out bundler paths for subsequent OpenStudio CLI calls 
# This is a work-around for the CLI call inside OpenStudio-standards gem
# when measures invoke sizing runs
require 'bundler'
Bundler.setup
Bundler.require

ENV["BUNDLE_PATH"] = nil
ENV["BUNDLE_GEMFILE"] = nil

# **END** 



osw_path = ARGV[1]
osw_dir = File.dirname(osw_path)

# Run workflow.osw
run_options = Hash.new
run_options[:debug] = debug
run_options[:preserve_run_dir] = true # because we are running in .

# do the run
k = OpenStudio::Workflow::Run.new(osw_path, run_options)
final_state = k.run

if final_state == :errored 
  exit(1)
end