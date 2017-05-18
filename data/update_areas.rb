######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

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
  distance = 0
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
    
    polygon.each_index do |i|
      if i == (polygon.size-1)
        distance += OpenStudio::getDistance(floor_print[i], floor_print[0])
      else
        distance += OpenStudio::getDistance(floor_print[i], floor_print[i+1])
      end
    end
  end
  
  if number_of_stories == 0
    floor_area = area
  else
    floor_area = number_of_stories*area
  end
  
  properties[:footprint_area] = OpenStudio::convert(area, 'm^2', 'ft^2').get
  properties[:footprint_perimeter] = OpenStudio::convert(distance, 'm', 'ft').get
  properties[:floor_area] = OpenStudio::convert(floor_area, 'm^2', 'ft^2').get
  properties[:number_of_stories] = number_of_stories
  properties[:maximum_roof_height] = maximum_roof_height
  
  #Point3d toLocalCartesian(const PointLatLon& point) const;
  #std::vector<Point3d> toLocalCartesian(const std::vector<PointLatLon>& points) const;
end

File.open(ARGV[0], 'w') do |file|
  file << JSON::pretty_generate(geojson)
end