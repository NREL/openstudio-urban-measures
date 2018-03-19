######################################################################
#  Copyright © 2016-2017 the Alliance for Sustainable Energy, LLC, All Rights Reserved
#
#  This computer software was produced by Alliance for Sustainable Energy, LLC under Contract No. DE-AC36-08GO28308 with the U.S. Department of Energy. For 5 years from the date permission to assert copyright was obtained, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, and perform publicly and display publicly, by or on behalf of the Government. There is provision for the possible extension of the term of this license. Subsequent to that period or any extension granted, the Government is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide license in this software to reproduce, prepare derivative works, distribute copies to the public, perform publicly and display publicly, and to permit others to do so. The specific term of the license can be identified by inquiry made to Contractor or DOE. NEITHER ALLIANCE FOR SUSTAINABLE ENERGY, LLC, THE UNITED STATES NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
######################################################################

require 'rubygems'
require 'json-schema'
require_relative 'clean_common.rb'

class TestdatenCleaner < Cleaner
  def name
    return 'Testdaten'
  end

  # return a string that will match files to clean in glob
  def file_pattern
    return 'Testdaten-LoD2S2-CityGML.2.geojson'
  end

  def clean_building(data, schema)
    data['source_id'] = data['id']
    data['source_name'] = 'Testdaten'
    data['surface_elevation'] = data['elevation'].to_f
    data['roof_elevation'] = data['elevation'].to_f + data['measuredHeight'].to_f
    data['space_type'] = 'Office' # "function": "31001_2463",
    # "Gebaeudehoehe": "2.373", # Building height
    # "Bodenhoehe": "168.721", # Floor height
    # "Dachform": "PULTDACH", # Roof shape, PENT ROOF
    # "Dachhoehe": "171.095", # Roof Height
    # "Gemeindeschluessel": "08125005", # Municipality key
    # "DatenquelleLage": "1000", # Data source location
    # "DatenquelleBodenhoehe": "1100", # Data source ground
    # "DatenquelleDachhoehe": "5000", # Data source roof height
    # "roofType": "2100",
    data['number_of_stories'] = data['storeysAboveGround'].to_i
    data['number_of_stories_above_ground'] = data['storeysAboveGround'].to_i
    data['number_of_stories_below_ground'] = 0
    data['floor_area'] = 0

    data['intersecting_building_source_ids'] = []
    data['weather_file_name'] = 'Testdaten.epw'

    super(data, schema)
  end

  def clean_taxlot(data, schema)
    super(data, schema)
  end

  def clean_region(data, schema)
    data['weather_file_name'] = 'Testdaten.epw'

    super(data, schema)
  end
end

cleaner = TestdatenCleaner.new
# cleaner.clean_originals
# cleaner.gather_stats
cleaner.clean
cleaner.write_csvs
