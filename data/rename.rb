require 'fileutils'

Dir.glob('*.js').each do |p|
  new_name = p.gsub('.js', '.geojson')
  FileUtils.mv(p, new_name)
end