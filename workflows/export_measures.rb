# exports measures in an OSW to a directory
# ruby export_measures.rb /path/to/osw /export/dir

require 'openstudio'
require 'fileutils'

puts ARGV[0]
workflow = OpenStudio::WorkflowJSON.load(OpenStudio.toPath(ARGV[0])).get

export_dir = ARGV[1]
if !File.exist?(export_dir)
  FileUtils.mkdir_p(export_dir)
end

workflow.workflowSteps.each do |step|
  measure_dir_name = step.to_MeasureStep.get.measureDirName
  puts measure_dir_name
  measure_path = workflow.findMeasure(measure_dir_name)
  if !measure_path.empty?
    FileUtils.cp_r(measure_path.get.to_s, File.join(export_dir, measure_dir_name))
  end
end
