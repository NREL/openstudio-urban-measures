require 'json'

dirs = Dir.glob("./run/testing*")

euis = []
failed = []
num_success = 0
num_failed = 0
dirs.each do |osw_dir|
  ['baseline', 'retrofit'].each do |workflow|
    if File.exists?(File.join(osw_dir, workflow, "run/failed.job"))
      failed << "#{osw_dir}/#{workflow} failed to run"
      num_failed += 1
    else
      num_success += 1
    end
    
    if File.exists?(File.join(osw_dir, workflow, "out.osw"))
      File.open(File.join(osw_dir, workflow, "out.osw"), 'r') do |f|
        out_osw = JSON::parse(f.read, :symbolize_names => true)
        if out_osw[:steps]
          out_osw[:steps].each do |step|
            if step[:measure_dir_name] == 'StandardReports'
              if step[:result] && step[:result][:step_values]
                step[:result][:step_values].each do |result|
                  if result[:name] == 'eui'
                    euis << "#{osw_dir}/#{workflow} EUI = #{result[:value]}"
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

euis.each {|eui| puts eui}

failed.each {|failure| puts failure}
puts "#{num_failed} failures"
puts "#{num_success} success"