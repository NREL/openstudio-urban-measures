require 'openstudio-workflow'

osw_path = ARGV[0]
osw_dir = File.dirname(osw_path)

# Create local adapters
adapter_options = {workflow_filename: File.basename(osw_path), output_directory: File.join(osw_dir, 'run')}
input_adapter = OpenStudio::Workflow.load_input_adapter 'local', adapter_options
output_adapter = OpenStudio::Workflow.load_output_adapter 'local', adapter_options

# Run workflow.osw
run_options = Hash.new

k = OpenStudio::Workflow::Run.new input_adapter, output_adapter, osw_dir, run_options
final_state = k.run