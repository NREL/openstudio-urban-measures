
require 'openstudio'
require 'fileutils'

desc 'update residential measures'
task :update_residential_measures do

      ["urban_building_type", "urban_building_type_e_plus"].each do |measure|
      
        ["resources", "measures"].each do |folder|
  
          command = "svn checkout https://github.com/NREL/OpenStudio-Beopt/trunk/#{folder} ./measures/#{measure}/resources/#{folder}"
          system(command)
          if folder == "measures"
            update_residential_resources(measure)
            measures_dir = OpenStudio::toPath(File.dirname(__FILE__) + "/measures/#{measure}/resources/measures")
            measures_zip = OpenStudio::toPath(File.dirname(__FILE__) + "/measures/#{measure}/resources/measures.zip")
            zip_file = OpenStudio::ZipFile.new(measures_zip, false)
            zip_file.addDirectory(measures_dir, OpenStudio::toPath("/"))
          end
            
        end
        FileUtils.rm_rf("./measures/#{measure}/resources/measures")
        FileUtils.rm_rf("./measures/#{measure}/resources/resources")
        
      end
      
end

def update_residential_resources(measure_name)

  require 'openstudio'

  measures = Dir.entries(File.expand_path("../measures/#{measure_name}/resources/measures/", __FILE__)).select {|entry| File.directory? File.join(File.expand_path("../measures/#{measure_name}/resources/measures/", __FILE__), entry) and !(entry =='.' || entry == '..') }
  measures.each do |m|
    measurerb = File.expand_path("../measures/#{measure_name}/resources/measures/#{m}/measure.rb", __FILE__)
    
    # Get recursive list of resources required based on looking for 'require FOO' in rb files
    resources = get_requires_from_file(measurerb, measure_name)

    # Add any additional resources specified in resources.csv
    subdir_resources = {} # Handle resources in subdirs
    File.open(File.expand_path("../measures/#{measure_name}/resources/resources/resources.csv", __FILE__)) do |file|
      file.each do |line|
        line = line.chomp.split(',').reject { |l| l.empty? }
        measure = line.delete_at(0)
        next if measure != m
        line.each do |resource|
          fullresource = File.expand_path("../measures/#{measure_name}/resources/resources/#{resource}", __FILE__)
          next if resources.include?(fullresource)
          resources << fullresource
          if resource != File.basename(resource)
            subdir_resources[File.basename(resource)] = resource
          end
        end
      end
    end  
    
    # Add/update resource files as needed
    resources.each do |resource|
      if not File.exist?(resource)
        puts "Cannot find resource: #{resource}."
        next
      end
      r = File.basename(resource)
      dest_resource = File.expand_path("../measures/#{measure_name}/resources/measures/#{m}/resources/#{r}", __FILE__)
      measure_resource_dir = File.dirname(dest_resource)
      if not File.directory?(measure_resource_dir)
        FileUtils.mkdir_p(measure_resource_dir)
      end
      if not File.file?(dest_resource)
        FileUtils.cp(resource, measure_resource_dir)
        puts "Added #{r} to #{m}/resources."
      elsif not FileUtils.compare_file(resource, dest_resource)
        FileUtils.cp(resource, measure_resource_dir)
        puts "Updated #{r} in #{m}/resources."
      end
    end
    
    # Any extra resource files?
    if File.directory?(File.expand_path("../measures/#{measure_name}/resources/measures/#{m}/resources", __FILE__))
      Dir.foreach(File.expand_path("../measures/#{measure_name}/resources/measures/#{m}/resources", __FILE__)) do |item|
        next if item == '.' or item == '..'
        if subdir_resources.include?(item)
          item = subdir_resources[item]
        end
        resource = File.expand_path("../measures/#{measure_name}/resources/resources/#{item}", __FILE__)
        next if resources.include?(resource)
        puts "Extra file #{item} found in #{m}/resources. Do you want to delete it? (y/n)"
        input = STDIN.gets.strip.downcase
        next if input != "y"
        FileUtils.rm(File.expand_path("../measures/#{measure_name}/resources/measures/#{m}/resources/#{item}", __FILE__))
        puts "File deleted."
      end
    end
    
    # Update measure xml
    measure_dir = File.expand_path("../measures/#{measure_name}/resources/measures/#{m}/", __FILE__)
    measure = OpenStudio::BCLMeasure.load(measure_dir)
    if not measure.empty?
        begin
            measure = measure.get

            file_updates = measure.checkForUpdatesFiles # checks if any files have been updated
            xml_updates = measure.checkForUpdatesXML # only checks if xml as loaded has been changed since last save
      
            if file_updates || xml_updates

                # try to load the ruby measure
                info = OpenStudio::Ruleset.getInfo(measure, OpenStudio::Model::OptionalModel.new, OpenStudio::OptionalWorkspace.new)
                info.update(measure)

                measure.save
            end
            
            
        rescue Exception => e
            puts e.message
        end
    end
   
  end

end

def get_requires_from_file(filerb, measure_name)
  requires = []
  if not File.exists?(filerb)
    return requires
  end
  File.open(filerb) do |file|
    file.each do |line|
      line.strip!
      next if line.nil?
      next if not (line.start_with?("require \"\#{File.dirname(__FILE__)}/") or line.start_with?("require\"\#{File.dirname(__FILE__)}/"))
      line.chomp!("\"")
      d = line.split("/")
      requirerb = File.expand_path("../measures/#{measure_name}/resources/resources/#{d[-1].to_s}.rb", __FILE__)
      requires << requirerb
    end
  end
  # Recursively look for additional requirements
  requires.each do |requirerb|
    get_requires_from_file(requirerb, measure_name).each do |rb|
      next if requires.include?(rb)
      requires << rb
    end
  end
  return requires
end