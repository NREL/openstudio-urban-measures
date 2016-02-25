class Cleaner

  def get_building_schema
    result = nil
    File.open(File.dirname(__FILE__) + "/../building_properties.json") do |f|
      result = JSON.parse(f.read)
    end
    return result
  end

  def get_taxlot_schema
    result = nil
    File.open(File.dirname(__FILE__) + "/../taxlot_properties.json") do |f|
      result = JSON.parse(f.read)
    end
    return result
  end

  def get_district_system_schema
    result = nil
    File.open(File.dirname(__FILE__) + "/../district_system_properties.json") do |f|
      result = JSON.parse(f.read)
    end
    return result
  end

  def get_region_schema
    result = nil
    File.open(File.dirname(__FILE__) + "/../region_properties.json") do |f|
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

  # override in derived class
  
  # return a string that identifies this cleaner
  def name()
    return ""
  end
  
  # return a string that will match files to clean in glob
  def file_pattern()
    return ""
  end

  def clean_building(data, schema)
    # clean
    remove_nil_values(data)
    remove_unknown_keys(data, schema)
  
    # validate
    errors = JSON::Validator.fully_validate(schema, data, :errors_as_objects => true)
    return errors
  end

  def clean_taxlot(data, schema)
    # clean
    remove_nil_values(data)
    remove_unknown_keys(data, schema)
  
    # validate
    errors = JSON::Validator.fully_validate(schema, data, :errors_as_objects => true)
    return errors
  end
  
  def clean_region(data, schema)
    # clean
    remove_nil_values(data)
    remove_unknown_keys(data, schema)
  
    # validate
    errors = JSON::Validator.fully_validate(schema, data, :errors_as_objects => true)
    return errors
  end
  
  def clean
    all_errors = {}
    
    building_schema = get_building_schema
    taxlot_schema = get_taxlot_schema
    region_schema = get_region_schema
    pattern = file_pattern
    
    Dir.glob(pattern).each do |p|
      
      # enforce .geojson extension
      next unless /\.geojson$/.match(p)
      
      # skip already cleaned
      next if /\.clean\.geojson$/.match(p)
      
      #next unless /08031004103/.match(p)
      
      puts "Processing #{p}"
      
      geojson = nil
      File.open(p, 'r') do |f|
        geojson = JSON.parse(f.read)
      end
      
      # loop over features in original and sort keys
      geojson['features'].each do |feature|
        data = feature['properties']
        feature['properties'] = Hash[data.sort]
      end

      File.open(p, 'w') do |f|
        #f << JSON.generate(geojson)
        f << JSON.pretty_generate(geojson)
      end
      
      all_errors[p] = []
      
      # loop over features
      geojson['features'].each do |feature|
        all_errors[p] << []
        
        begin
          data = feature['properties']
          type = data['type']
          
          errors = []
          if /building/i.match(type)
            errors = clean_building(data, building_schema)
          elsif /taxlot/i.match(type)
            errors = clean_taxlot(data, taxlot_schema)
          elsif /region/i.match(type)
            errors = clean_region(data, region_schema)
          else 
            raise("Unknown type: '#{type}'")
          end
          
          if !errors.empty?
            all_errors[p][-1] << "Validation failed"
            all_errors[p][-1].concat(errors)
            all_errors[p][-1] << "Removing feature: "
            all_errors[p][-1] << data.clone
            feature.clear
          else
            feature['properties'] = Hash[data.sort]
          end
          
        rescue Exception => e  
          all_errors[p][-1] << "Error '#{e.message}' occurred: "
          all_errors[p][-1] << "#{e.backtrace}"
          all_errors[p][-1] << "Removing feature: "
          all_errors[p][-1] << data.clone
          feature.clear
        end
        
        if all_errors[p][-1].empty?
          all_errors[p].pop
        end
      end
      
      geojson['features'].delete_if {|feature| feature.keys.empty?}
      
      File.open(p.gsub('.geojson', '.clean.geojson'), 'w') do |f|
        #f << JSON.generate(geojson)
        f << JSON.pretty_generate(geojson)
      end
      
    end

    File.open("#{name}_errors.json", 'w') do |f|
      f << JSON.pretty_generate(all_errors)
    end
  end
  
end