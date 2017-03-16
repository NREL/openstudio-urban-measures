require 'json'

dirs = Dir.glob("./run/*/datapoint*/")

euis = []
failed = []
num_failed = 0
dirs.each do |osw_dir|
  if File.exists?(File.join(osw_dir, "run/failed.job"))
    failed << "#{osw_dir} failed to run"
    num_failed += 1
  end
  
  if File.exists?(File.join(osw_dir, "out.osw"))
    File.open(File.join(osw_dir, "out.osw"), 'r') do |f|
      out_osw = JSON::parse(f.read, :symbolize_names => true)
      if out_osw[:steps]
        out_osw[:steps].each do |step|
          if step[:measure_dir_name] == 'datapoint_reports'
            if step[:result] && step[:result][:step_values]
              step[:result][:step_values].each do |result|
                if result[:name] == 'total_site_eui'
                  euis << "#{osw_dir} EUI = #{result[:value]}"
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