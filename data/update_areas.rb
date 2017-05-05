require 'openstudio'
require 'json'

file = ARGV[0]

geojson = JSON::parse(File.open(file,'r').read, :symbolize_names=>true)

geojson[:features].each do |feature|
  properties = feature[:properties]
  geometry = feature[:geometry]
  
  number_of_stories = properties[:number_of_stories]
  if number_of_stories.nil? 
    number_of_stories = 1
  end
  
  maximum_roof_height = properties[:maximum_roof_height]
  #if maximum_roof_height.nil?
    maximum_roof_height = 10*number_of_stories
  #end

  multi_polygons = nil
  if geometry[:type] == "Polygon"
    polygons = geometry[:coordinates]
    multi_polygons = [polygons]
  elsif geometry[:type] == "MultiPolygon"
    multi_polygons = geometry[:coordinates]
  end
  
  area = 0
  multi_polygons[0].each do |polygon|
    origin_lat_lon = nil
    floor_print = OpenStudio::Point3dVector.new
    polygon.each do |p|
      lon = p[0]
      lat = p[1]
      origin_lat_lon = OpenStudio::PointLatLon.new(lat, lon, 0) if origin_lat_lon.nil?
      point_3d = origin_lat_lon.toLocalCartesian(OpenStudio::PointLatLon.new(lat, lon, 0))
      point_3d = OpenStudio::Point3d.new(point_3d.x, point_3d.y, 0)
      floor_print << point_3d
    end
    area += OpenStudio::getArea(floor_print).get
  end
    
  if number_of_stories == 0
    floor_area = OpenStudio::convert(area, 'm', 'ft').get
  else
    floor_area = number_of_stories*OpenStudio::convert(area, 'm', 'ft').get
  end
  
  properties[:floor_area] = floor_area
  properties[:number_of_stories] = number_of_stories
  properties[:maximum_roof_height] = maximum_roof_height
  
  #Point3d toLocalCartesian(const PointLatLon& point) const;
  #std::vector<Point3d> toLocalCartesian(const std::vector<PointLatLon>& points) const;
end

File.open(ARGV[0], 'w') do |file|
  file << JSON::pretty_generate(geojson)
end