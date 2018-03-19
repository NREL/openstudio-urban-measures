require 'fileutils'

require 'openstudio_measure_tester/rake_task'
OpenStudioMeasureTester::RakeTask.new

task :default => [:setup]

task :setup do
  if !File.exists?('config.rb')
    FileUtils.cp('config.rb.in', 'config.rb')
  end

  require_relative 'config'
  
  if File.exists?('openstudio-measures')
    FileUtils.rm_rf('openstudio-measures')
  end
  
  if UrbanOptConfig::OPENSTUDIO_MEASURES
    if File.exists?(UrbanOptConfig::OPENSTUDIO_MEASURES)
      if /mswin/.match(RUBY_PLATFORM) || /mingw/.match(RUBY_PLATFORM)
        #symlinks require admin priveledges on windows, just copy
        FileUtils.cp_r(UrbanOptConfig::OPENSTUDIO_MEASURES, './openstudio-measures')
      else
        # do same on Mac for consistency
        FileUtils.cp_r(UrbanOptConfig::OPENSTUDIO_MEASURES, './openstudio-measures')
        #FileUtils.ln_s(UrbanOptConfig::OPENSTUDIO_MEASURES, 'openstudio-measures')
      end
    else
      raise "#{UrbanOptConfig::OPENSTUDIO_MEASURES} path does not exist"
    end
  end
end