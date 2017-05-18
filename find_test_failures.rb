######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

require 'json'

dirs = Dir.glob("./run/testing/*")

euis = []
failed = []
num_success = 0
num_failed = 0
dirs.each do |osw_dir|
  if File.exists?(File.join(osw_dir, "run/failed.job"))
    failed << "#{osw_dir} failed to run"
    num_failed += 1
  else
    num_success += 1
  end
  
  if File.exists?(File.join(osw_dir, "out.osw"))
    File.open(File.join(osw_dir, "out.osw"), 'r') do |f|
      out_osw = JSON::parse(f.read, :symbolize_names => true)
      if out_osw[:steps]
        out_osw[:steps].each do |step|
          if step[:measure_dir_name] == 'openstudio_results'
            if step[:result] && step[:result][:step_values]
              step[:result][:step_values].each do |result|
                if result[:name] == 'eui'
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
puts "#{num_success} success"
puts

failed.each {|failure| puts failure}
puts "#{num_failed} failures"
