# convert CityGML to GeoJSON using instructions in convert_citygml.txt
# this script merges other information in the CityGML with the exported GeoJSON

require 'nokogiri'
require 'json'

doc = nil
File.open('Testdaten-LoD2S2-CityGML.gml') do |file|
  doc = Nokogiri::XML(file)
end

json = nil
File.open('Testdaten-LoD2S2-CityGML.geojson') do |file|
  json = JSON::parse(file.read, :symbolize_names => true)
end


bldg_elements = ['bldg:function', 'bldg:roofType', 'bldg:measuredHeight', 'bldg:storeysAboveGround']

doc.xpath('//bldg:Building').each do |node|
  id = node.attr('gml:id').to_s
  feature = json[:features].find {|feature| feature[:properties][:id] == id}
  next if feature.nil?
  
  node.xpath('gen:stringAttribute').each do |att|
    name = att.attr('name').to_s
    value = att.at_xpath('gen:value').text
    feature[:properties][name] = value
  end
  
  bldg_elements.each do |bldg_element|
    name = bldg_element.gsub('bldg:', '')
    value = node.at_xpath(bldg_element)
    if value
      feature[:properties][name] = value.text
    end
  end
  
end

File.open('Testdaten-LoD2S2-CityGML.2.geojson', 'w') do |file|
  file = JSON::pretty_generate(json)
end