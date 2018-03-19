######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

require 'nokogiri'
require 'json'

doc = nil
File.open('Testdaten-LoD2S2-CityGML.gml') do |file|
  doc = Nokogiri::XML(file)
end

json = nil
File.open('Testdaten-LoD2S2-CityGML.geojson') do |file|
  json = JSON.parse(file.read, symbolize_names: true)
end

bldg_elements = ['bldg:function', 'bldg:roofType', 'bldg:measuredHeight', 'bldg:storeysAboveGround']

doc.xpath('//bldg:Building').each do |node|
  id = node.attr('gml:id').to_s
  feature = json[:features].find { |feature| feature[:properties][:id] == id }
  if feature.nil?
    puts "Can't find feature #{id}"
    next
  end
  puts "Found feature #{id}"

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
  file << JSON.generate(json)
end
