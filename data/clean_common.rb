def get_building_schema
  result = nil
  File.open(File.dirname(__FILE__) + "/../building_properties.json") do |f|
    result = JSON.parse(f.read)
  end
  return result
end

def remove_nil_values(data)
  data.keys.each do |key|
    if data[key].nil?
      data.delete(key)
    end
  end
end

def remove_unknown_keys(data, schema)
  data.keys.each do |key|
    if schema['properties'][key].nil?
      data.delete(key)
    end
  end
end

def infer_geometry(data)
end

def infer_space_type(data)
end

def clean_buildings(city)

  all_errors = {}
  
  building_schema = get_building_schema
  
  Dir.glob("#{city}_bldg_footprints_*.geojson").each do |p|

    # skip already cleaned
    next if /\.clean\.geojson$/.match(p)
    
    geojson = nil
    File.open(p, 'r') do |f|
      geojson = JSON.parse(f.read)
    end
    
    # loop over features
    geojson['features'].each do |feature|
      all_errors[p] = []
      
      begin
        data = feature['properties']
        
        # clean
        infer_geometry(data)
        infer_space_type(data)
        remove_nil_values(data)
        remove_unknown_keys(data, building_schema)
      
        # validate
        errors = JSON::Validator.fully_validate(building_schema, data, :errors_as_objects => true)
        all_errors[p].concat(errors)
      rescue
        all_errors[p] << "Removing feature:\n#{data}"
        feature.clear
      end
    end
    
    geojson['features'].delete_if {|feature| feature.keys.empty?}
    
    File.open(p.gsub('.geojson', '.clean.geojson'), 'w') do |f|
      #f << JSON.generate(geojson)
      f << JSON.pretty_generate(geojson)
    end

    break
  end

  File.open("#{city}_errors.json", 'w') do |f|
    f << JSON.generate(all_errors)
  end
end
