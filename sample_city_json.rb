require 'csv'
require 'fileutils'
require 'json'

# samples the city.json file and writes out a variable description for the os analysis spreadsheet

city_json = ARGV[0]

if !File.exists?(city_json)
  raise "city_json = #{city_json} does not exist"
end

buildings = {}
File.open(city_json,"r") do |f|
  buildings = JSON.parse(f.read, {:symbolize_names=>true})
end

building_ids = []
buildings.each_value do |building|
  building_ids << building[:bldg_fid]
end

#building_ids = building_ids.slice(0,100)
n = building_ids.length
weights = Array.new(n, (1.0/n).round(8))

join_str = "','"
puts "n = #{n}"
puts "building_ids = |'#{building_ids.join(join_str)}'|"
puts "building_ids = ['#{building_ids.join(join_str)}']"
puts "weights = [#{weights.join(',')}]"

