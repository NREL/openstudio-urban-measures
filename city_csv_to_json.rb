require 'csv'
require 'fileutils'
require 'json'

# converts building and points csv files to a JSON format

buildings_csv = ARGV[0]
points_csv = ARGV[1]
out_json = ARGV[2]

if !File.exists?(buildings_csv)
  raise "buildings_csv = #{buildings_csv} does not exist"
end

if !File.exists?(points_csv)
  raise "points_csv = #{points_csv} does not exist"
end

CSV::Converters[:blank_to_nil] = lambda do |field|
  field && field.empty? ? nil : field
end

buildings = {}
File.open(buildings_csv, 'r') do |file|
  csv = CSV.new(file, :headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil])
  rows = csv.to_a.map {|row| row.to_hash }
  rows.each do |row|
    row[:points] = []
    buildings[row[:bldg_fid]] = row
  end
end

File.open(points_csv, 'r') do |file|
  csv = CSV.new(file, :headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil])
  rows = csv.to_a.map {|row| row.to_hash }
  rows.each do |row|
    if buildings[row[:bldg_fid]]
      buildings[row[:bldg_fid]][:points] << row
    else
      puts "Can't find building #{row[:bldg_fid]}"
    end
  end
end

buildings.each_value do |building|
  building[:points].sort! do |x, y| 
    result = x[:multi_part_plygn_index].to_i <=> y[:multi_part_plygn_index].to_i
    result = x[:plygn_index].to_i <=> y[:plygn_index].to_i if result == 0
    result = x[:point_order].to_i <=> y[:point_order].to_i if result == 0
    result
  end
end

puts "writing file out_json = #{out_json}"

File.open(out_json,"w") do |f|
  f << JSON.pretty_generate(buildings)
end