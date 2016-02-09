# Geometry class
class Geometry
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :type, type: String
  field :coordinates, type: Array  # format order for coordinates is: [long, lat]
  field :centroid, type: Array

  # Validation

  # Relations
  has_one :building, autosave: true, dependent: :destroy
  has_one :taxlot, autosave: true, dependent: :destroy
  has_one :district_system, autosave: true, dependent: :destroy
  has_one :region, autosave: true, dependent: :destroy

  # Indexes
  index({ centroid: "2d" }, { min: -200, max: 200 })

  # read in geojson file from file upload
 def self.read_geojson_file(file_data)
    if file_data.class.to_s == 'Hash'
      data = file_data
    elsif file_data.respond_to?(:read)
      file = file_data.read
      data = MultiJson.load(file, :symbolize_keys => true)
    elsif file_data.respond_to?(:path)
      file = File.read(file_data.path)
      data = MultiJson.load(file, :symbolize_keys => true)
    else
      logger.error "Bad file_data: #{file_data.class.name}: #{file_data.inspect}"
      data = nil
    end
    return data
  end

  # this method is to be used to create/update a single feature (building, taxlot, region, or district system)
  # expects only 1 item in the file if an object is passed in
  # expects a feature collection if no object is passed in
  def self.create_update_feature(data, object=nil)

    error = false
    message = ''
    is_bulk = false
    saved_objects = 0

    if data[:crs][:properties][:name] != 'EPSG:4326'
      error = true
      message += 'Cannot upload coordinate systems other than EPSG:4326.'

    else
      features = data[:features] ? data[:features] : []
      total_count = features.count
      
      # if no object, API bulk processing
      # otherwise, only process first item in features array
      if object.nil?
        items = features
        is_bulk = true
      else
        items = [features.first]
      end

      items.each do |item|
      
        if item[:properties]
          properties = item[:properties]
        else
          properties = nil
          error = true
          message += "Missing properties for data item."
        end

        # instantiate object
        if is_bulk
          # TODO: make this better.  Will there be a "type" variable?
          if properties[:bldg_fid] && properties[:bldg_fid] != 'null'
            # ID provided?
            if properties[:id] && properties[:id] != 'null'
              object = Building.find_or_create_by(id: properties[:id])
            else
              # TODO: find_or_create by source_id & source_name ?
              object = Building.find_or_create_by(bldg_fid: properties[:bldg_fid])
            end   
            object.type = 'building'
          # TAXLOT
          elsif properties[:lot_fid] && properties[:lot_fid] != 'null'
            # ID provided?
            if properties[:id] && properties[:id] != 'null'
              object = Taxlot.find_or_create_by(id: properties[:id])
            else
              # TODO: find_or_create by source_id & source_name 
              object = Taxlot.find_or_create_by(lot_fid: properties[:lot_fid])
            end
            object.type = 'taxlot'
          end
          # TODO: regions and district systems
        end

        unless properties.nil?
         
          properties.each do |key, value|
            if value != 'null'
              object[key] = value
            end
          end

          # geojson fields are under geometry
          if item[:geometry]
            geometry = item[:geometry]
            if object.geometry.nil?
              @geometry = Geometry.new

              # set association
              association = object.class.name.downcase
              if association == 'building'
                object.type = 'building'
                @geometry.building = object
              elsif association == 'taxlot'
                object.type = 'taxlot'
                @geometry.taxlot = object
              elsif association == 'region'
                object.type = 'region'
                @geometry.region = object
              elsif association == 'district system'
                object.type = 'district_system'
                @geometry.district_system = object  
              end
            else
              @geometry = object.geometry
            end

            @geometry.type = geometry[:type]
            @geometry.coordinates = geometry[:coordinates]
            @geometry.centroid = calculate_centroid(@geometry.coordinates, @geometry.type)

            if @geometry.save!
              saved_objects += 1
            else
              error = true
              message += "Could not process: #{@geometry.errors}."
            end
          end
        end
      end
    end

    unless error
      message = "Created #{saved_objects} features."
    end

    return object, error, message
  end

  # build geoJSON for a feature collection
  def self.build_geojson(results)

    json_hash = {}

    # this doesn't change
    json_hash[:crs] = { type: 'name', properties: { name: "EPSG:4326" }}
    json_hash[:type] = 'FeatureCollection'

    # iterate through results
    json_hash[:features] = []
    results.each do |res|
  
      json_hash[:features] << build_feature(res)

    end

    # convert to json
    json_data = MultiJson.dump(json_hash)

  end

  # building geoJSON for a single feature
  def self.build_feature(result)
  
    res_hash = {}
    res_hash[:geometry] = {type: result.geometry.type, coordinates: result.geometry.coordinates}
    res_hash[:type] = 'Feature'
    res_hash[:properties] = {}
    result.attributes.each do |key, value|
      # convert _id to id
      # remove geometry_id
      if key == '_id'
        res_hash[:properties][:id] = value.to_s
      elsif key != 'geometry_id'
        res_hash[:properties][key] = value
      end
    end 
    res_hash
  end

  # calculate centroid of polygon or multipolygon 
  def self.calculate_centroid(coordinates, type)
    if type == 'Polygon'
      points = coordinates[0]
    else
      # assume multipolygon
      points = coordinates[0][0]
    end
    logger.info("POINTS: #{points}")
    centroid = points.transpose.map{|c| c.inject{|a, b| a + b}.to_f / c.size}
    logger.info("CENTROID: #{centroid}")

    return centroid
  end

end
