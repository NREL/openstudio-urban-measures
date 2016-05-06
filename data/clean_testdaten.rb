require 'rubygems'
require 'json-schema'
require_relative 'clean_common.rb'


class TestdatenCleaner < Cleaner

  def name()
    return "Testdaten"
  end
  
  # return a string that will match files to clean in glob
  def file_pattern()
    return "Testdaten-LoD2S2-CityGML.2.geojson"
  end
  
  
  def clean_building(data, schema)

    data['source_id'] = data['id']
    data['source_name'] = 'Testdaten'
    data['surface_elevation'] = data['elevation'].to_f
    data['roof_elevation'] = data['elevation'].to_f + data['measuredHeight'].to_f
    data['space_type'] = 'Office' # "function": "31001_2463",
    #"Gebaeudehoehe": "2.373", # Building height
    #"Bodenhoehe": "168.721", # Floor height 
    #"Dachform": "PULTDACH", # Roof shape, PENT ROOF 
    #"Dachhoehe": "171.095", # Roof Height 
    #"Gemeindeschluessel": "08125005", # Municipality key 
    #"DatenquelleLage": "1000", # Data source location
    #"DatenquelleBodenhoehe": "1100", # Data source ground
    #"DatenquelleDachhoehe": "5000", # Data source roof height 
    #"roofType": "2100",
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
#cleaner.clean_originals
#cleaner.gather_stats
cleaner.clean
cleaner.write_csvs