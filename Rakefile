
require 'openstudio'
require 'fileutils'

desc 'update residential measures'
task :update_residential_measures do

      rev = '4527658'
      ["urban_building_type", "urban_building_type_e_plus"].each do |measure|
  
        command = "svn checkout -r #{rev} https://github.com/NREL/OpenStudio-Beopt/trunk/measures ./measures/#{measure}/resources/measures"
        system(command)
        measures_dir = OpenStudio::toPath(File.dirname(__FILE__) + "/measures/#{measure}/resources/measures")
        measures_zip = OpenStudio::toPath(File.dirname(__FILE__) + "/measures/#{measure}/resources/measures.zip")
        zip_file = OpenStudio::ZipFile.new(measures_zip, false)
        zip_file.addDirectory(measures_dir, OpenStudio::toPath("/"))
        FileUtils.rm_rf("./measures/#{measure}/resources/measures")
        
      end
      
end