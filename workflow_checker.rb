# Simple report of workflow steps (measure type, run order)
# USAGE: ruby workflow_checker.rb [path_to_workflow].osw
require 'json'
filename = ARGV[0]
file = File.read filename
wf = JSON.parse(file)
puts "Workflow integrity check (#{wf['steps'].size} steps):"
mt = ""
mtype = 0
wc = 0
wf['steps'].each_with_index do |step, i|
    warn = ''
    step['measure_definition']['attributes'].each do |a|
        if a['name'] == "Measure Type"
            if a['value'] == "ModelMeasure" && mtype > 0 || a['value'] == "EnergyPlusMeasure" && mtype > 1
                warn = '**'
                wc += 1
            end

            mt = a['value']
            if a['value'] == "EnergyPlusMeasure"
                mtype = 1
            elsif a['value'] == "ReportingMeasure"
                mtype = 2
            end
         end
    end
    puts "#{warn}STEP #{i} (#{mt}): #{step['name']}"
end
if wc > 0
    puts "WARNING: #{wc} workflow steps are out of type order (**)."
end
