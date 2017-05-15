######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#   
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

require 'json'
require 'rest-client'

user_name = 'test@nrel.gov'
user_pwd = 'testing123'

filenames = []
filenames << "#{File.dirname(__FILE__)}/grid_data_OR.geojson"
filenames << "#{File.dirname(__FILE__)}/grid_data_CO.geojson"
filenames << "#{File.dirname(__FILE__)}/denver_land_use_08031004103.clean.geojson"
filenames << "#{File.dirname(__FILE__)}/denver_bldg_footprints_08031004103.clean.geojson"

filenames.each do |filename|
  json_file = JSON.load(File.read(filename))
  json_request = JSON.generate('data' => json_file)

  #puts "POST http://localhost:3000/api/structures/batch_upload, parameters: #{json_request}"
  begin
    request = RestClient::Resource.new('http://localhost:3000/api/batch_upload', user: user_name, password: user_pwd)
    response = request.post(json_request, content_type: :json, accept: :json)
    puts "Status: #{response.code}"
    puts "SUCCESS: #{response.body}" if response.code == 201
  rescue => e
    puts "ERROR: #{e.response}"
  end
end