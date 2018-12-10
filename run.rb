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

$logger = Logger.new(STDOUT)
$logger.level = Logger::ERROR
#$logger.level = Logger::WARN
#$logger.level = Logger::DEBUG

OpenStudio::Logger.instance.standardOutLogger.enable
OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Error)
#OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Warn)
#OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Debug)

debug = true

osw_path = ARGV[1]
osw_dir = File.dirname(osw_path)

# Run workflow.osw
run_options = Hash.new
run_options[:debug] = debug
run_options[:preserve_run_dir] = true # because we are running in .

# do this if you want to postprocess 
# run_options[:jobs] = [
# { state: :queued, next_state: :initialization, options: { initial: true } },
# { state: :initialization, next_state: :reporting_measures, job: :RunInitialization,
#   file: 'openstudio/workflow/jobs/run_initialization.rb', options: {} },
# { state: :reporting_measures, next_state: :postprocess, job: :RunReportingMeasures,
#   file: 'openstudio/workflow/jobs/run_reporting_measures.rb', options: {} },
# { state: :postprocess, next_state: :finished, job: :RunPostprocess,
#   file: 'openstudio/workflow/jobs/run_postprocess.rb', options: {} },
# { state: :finished },
# { state: :errored }
# ]
# run_options[:preserve_run_dir] = true



# do the run
k = OpenStudio::Workflow::Run.new(osw_path, run_options)
final_state = k.run

if final_state == :errored 
  exit(1)
end