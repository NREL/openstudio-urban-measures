class Cleaner

  attr_accessor :current_warnings, :current_errors
  attr_accessor :raw_building_data, :clean_building_data
  
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
  
  def clean_polygon(polygon)
    polygon.each_index do |i|
      point = polygon[i]
      if point.size == 3
        polygon[i] = [point[0], point[1]]
      end
    end
  end
  
  def clean_geometry(geometry)
    geometry_type = geometry['type']
    if geometry_type == "Polygon"
      polygons = geometry['coordinates']
      polygons.each do |polygon|
        clean_polygon(polygon)
      end
    elsif geometry_type == "MultiPolygon"
      multi_polygons = geometry['coordinates']
      multi_polygons.each do |multi_polygon|
        multi_polygon.each do |polygon|
          clean_polygon(polygon)
        end
      end
    end
  end
  
  def clean_building(data, schema)
    # clean
    remove_nil_values(data)
    remove_unknown_keys(data, schema)
  
    # validate
    errors = JSON::Validator.fully_validate(schema, data, :errors_as_objects => true)
    @current_errors.concat(errors)
  end

  def clean_taxlot(data, schema)
    # clean
    remove_nil_values(data)
    remove_unknown_keys(data, schema)
  
    # validate
    errors = JSON::Validator.fully_validate(schema, data, :errors_as_objects => true)
    @current_errors.concat(errors)
  end
  
  def clean_region(data, schema)
    # clean
    remove_nil_values(data)
    remove_unknown_keys(data, schema)
  
    # validate
    errors = JSON::Validator.fully_validate(schema, data, :errors_as_objects => true)
    @current_errors.concat(errors)
  end
  
  def clean_originals
    pattern = file_pattern
    
    Dir.glob(pattern).each do |p|
      
      # enforce .geojson extension
      next unless /\.geojson$/.match(p)
      
      # skip already cleaned
      next if /\.clean\.geojson$/.match(p)
      
      puts "Cleaning #{p}"
      
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
 
    end
    
  end
  
  def make_stats(values)
    if values.empty?
      stats = "No data"
    else
      stats = "Min = #{values.min}, Max = #{values.max}"
    end
    return stats
  end
  
  def gather_stats
    pattern = file_pattern
    
    stats = {}
    Dir.glob(pattern).each do |p|
      
      # enforce .geojson extension
      next unless /\.geojson$/.match(p)
      
      # skip already cleaned
      next if /\.clean\.geojson$/.match(p)
      
      puts "Gathering Stats #{p}"
      
      geojson = nil
      File.open(p, 'r') do |f|
        geojson = JSON.parse(f.read)
      end
    
      # loop over features in original and sort keys
      geojson['features'].each do |feature|
        data = feature['properties']
        type = data['type']
        
        if stats[type].nil?
          stats[type] = {'count' => 0} 
        end
        stats[type]['count'] = stats[type]['count'] + 1
          
        data.each do |k, v|
          if stats[type][k].nil?
            stats[type][k] = {'count' => 0, 'values' => []} 
          end
          if !v.nil?
            stats[type][k]['count'] = stats[type][k]['count'] + 1
            stats[type][k]['values'] << v
          end
        end
      end
    end
    
    stats.each do |type, type_stats|
      type_count = type_stats['count']
      
      type_stats.each do |key, key_stats|
        next if key == 'count'
        
        key_count = key_stats['count']
        key_stats['percent'] = (100 * key_count.to_f / type_count.to_f).round(2)
        key_stats['values'].uniq!
        
        if key == 'address' ||
           key == 'census_block' ||
           key == 'census_block_group' ||
           key == 'census_tract' ||
           key == 'county_code' ||
           key == 'fips_code' ||
           key == 'intersecting_building_source_ids' ||
           key == 'legal_name' ||
           key == 'name' ||
           key == 'parent_region_source_id' ||
           key == 'region_ids' ||
           key == 'region_source_ids' ||
           key == 'source_id' ||
           key == 'taxlot_id' ||
           key == 'taxlot_source_id' ||
           key == 'zip_code'

          key_stats.delete('values')
           
        elsif key == 'average_roof_height' ||
            key == 'floor_area' ||
            key == 'footprint_area' || 
            key == 'footprint_perimeter' ||
            key == 'maximum_occupancy' ||
            key == 'maximum_roof_height' ||
            key == 'minimum_roof_height' ||
            key == 'number_of_residential_units' ||
            key == 'number_of_stories' ||
            key == 'roof_elevation' ||
            key == 'surface_elevation' ||
            key == 'year_built'
            
          key_stats['values'] = make_stats(key_stats['values'])
         
        else
        
          key_stats['values'].uniq!
        end
        
      end
    end
    
    File.open("#{name}_stats.json", 'w') do |f|
      #f << JSON.generate(geojson)
      f << JSON.pretty_generate(stats)
    end
  end
  
  def clean()
    all_errors = {}
    @raw_building_data = []
    @clean_building_data = []
    
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
      
      all_errors[p] = []
      
      # loop over features
      geojson['features'].each do |feature|
        all_errors[p] << []
        @current_warnings = []
        @current_errors = []   
        
        begin
          geometry = feature['geometry']
          clean_geometry(geometry)
          
          data = feature['properties']
          type = data['type']
          
          if type.nil?
            if data['CODE']
              if data['CODE'] == 'Building'
                type = 'Building'
                data['type'] = type
              elsif data['CODE'] == 'Courtyard'
                next
              end
            end
          end
          
          if /building/i.match(type)
            @raw_building_data << data.clone
            clean_building(data, building_schema)
            @clean_building_data << data.clone
          elsif /taxlot/i.match(type)
            clean_taxlot(data, taxlot_schema)
          elsif /region/i.match(type)
            clean_region(data, region_schema)
          else 
            raise("Unknown type: '#{type}'")
          end
          
          all_errors[p][-1].concat(@current_warnings)
          all_errors[p][-1].concat(@current_errors)
          
          if !@current_errors.empty?
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
  
  def write_csvs
  
    headers = Hash.new
    @raw_building_data.each do |data|
      data.keys.each do |key|
        headers[key] = 1
      end
    end
    @clean_building_data.each do |data|
      data.keys.each do |key|
        headers[key] = 1
      end
    end
    
    headers = headers.keys.sort
  
    File.open("#{name}_buildings_raw.csv", 'w') do |file|
      file.puts headers.join(',')
      @raw_building_data.each do |data|
        line = []
        headers.each do |key| 
          line << data[key].to_s.gsub(',',';')
        end
        file.puts line.join(',')
      end
    end
    
    File.open("#{name}_buildings_clean.csv", 'w') do |file|
      file.puts headers.join(',')
      @clean_building_data.each do |data|
        line = []
        headers.each do |key| 
          line << data[key].to_s.gsub(',',';')
        end
        file.puts line.join(',')
      end
    end
   end
   
end