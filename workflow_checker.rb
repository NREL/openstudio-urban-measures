# Simple report of workflow steps (measure type, run order)
# USAGE: ruby workflow_checker.rb [path_to_workflow].osw
require 'json'
filename = ARGV[0]
file = File.read filename
wf = JSON.parse(file)
puts "Workflow integrity check (#{wf['steps'].size} steps):"
mt = ""
wf['steps'].each_with_index do |step, i|
    step['measure_definition']['attributes'].each do |a|
        if a['name'] == "Measure Type"
            mt = a['value']
        end
    end
    puts "STEP #{i} (#{mt}): #{step['name']}"
end