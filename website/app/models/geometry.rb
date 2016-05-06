# Geometry class
class Geometry
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :type, type: String
  field :coordinates, type: Array # format order for coordinates is: [long, lat]
  field :centroid, type: Array # [ lng, lat] index

  # Validation

  # Relations
  belongs_to :building
  belongs_to :taxlot
  belongs_to :district_system
  belongs_to :region
  belongs_to :project

  # Indexes
  index({ centroid: '2d' }, min: -200, max: 200)
  index({project_id: 1})

  # read in geojson file from file upload
  def self.read_geojson_file(file_data)
    if file_data.class.to_s == 'Hash'
      data = file_data
    elsif file_data.respond_to?(:read)
      file = file_data.read
      data = MultiJson.load(file, symbolize_keys: true)
    elsif file_data.respond_to?(:path)
      file = File.read(file_data.path)
      data = MultiJson.load(file, symbolize_keys: true)
    else
      logger.error "Bad file_data: #{file_data.class.name}: #{file_data.inspect}"
      data = nil
    end
    data
   end

  # this method is to be used to create/update a single feature (building, taxlot, region, or district system)
  # expects only 1 item in the file if an object is passed in
  # expects a feature collection if no object is passed in
  # needs a project_id to add to
  def self.create_update_feature(data, project_id, object = nil)
    error = false
    message = ''
    is_bulk = false
    saved_objects = 0

    if project_id.nil?
      error = true
      message += 'No project ID provided.'
    end

    if !error && data[:crs][:properties][:name] != 'EPSG:4326'
      error = true
      message += 'Cannot upload coordinate systems other than EPSG:4326.'

    else
      features = data[:features] ? data[:features] : []
      total_count = features.count
      logger.info("#{total_count} features in file")

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
          message += 'Missing properties for data item.'
        end

        # instantiate object
        if is_bulk
          # check type parameter
          if properties[:type] && properties[:type] != 'null'
            case properties[:type]
            when 'Building'
              # ID provided?
              if properties[:id] && properties[:id] != 'null'
                object = Building.find_or_create_by(id: properties[:id])
              else
                # TODO: find_or_create by source_id & source_name
                # object = Building.find_or_create_by(bldg_fid: properties[:bldg_fid])
                object = Building.find_or_create_by(source_id: properties[:source_id], source_name: properties[:source_name])
              end
            when 'Taxlot'
              # ID provided?
              if properties[:id] && properties[:id] != 'null'
                object = Taxlot.find_or_create_by(id: properties[:id])
              else
                # TODO: find_or_create by source_id & source_name
                # object = Taxlot.find_or_create_by(lot_fid: properties[:lot_fid])
                object = Taxlot.find_or_create_by(source_id: properties[:source_id], source_name: properties[:source_name])
              end
            when 'Region'
              # ID provided
              if properties[:id] && properties[:id] != 'null'
                object = Region.find_or_create_by(id: properties[:id])
              else
                # TODO: find_or_create by source_id & source_name
                # object = Region.find_or_create_by(lot_fid: properties[:lot_fid])
                object = Region.find_or_create_by(source_id: properties[:source_id], source_name: properties[:source_name])
              end
            when 'District System'
              # ID provided
              if properties[:id] && properties[:id] != 'null'
                object = DistrictSystem.find_or_create_by(id: properties[:id])
              else
                # TODO: find_or_create by source_id & source_name
                # object = DistrictSystem.find_or_create_by(lot_fid: properties[:lot_fid])
                object = DistrictSystem.find_or_create_by(source_id: properties[:source_id], source_name: properties[:source_name])
              end
            else
              # don't process
              error = true
              message += 'No structure indicator (Building, Region...) in properties.'
            end
          end
        end

        next unless !error && !properties.nil?

        properties.each do |key, value|
          object[key] = value if value != 'null'
        end

        # set project_id
        object.project_id = project_id

        # geojson fields are under geometry
        # TODO: add project_id to geometry for indexing?
        next unless item[:geometry]
        geometry = item[:geometry]

        if object.geometry.nil?
          @geometry = Geometry.new
          object.geometry = @geometry
        else
          @geometry = object.geometry
        end

        @geometry.type = geometry[:type]
        @geometry.coordinates = geometry[:coordinates]
        @geometry.centroid = calculate_centroid(@geometry.coordinates, @geometry.type)
        # for queries
        @geometry.project_id = project_id

        if object.save!
          saved_objects += 1
        else
          error = true
          message += "Could not process: #{object.errors}."
          break
        end
      end
    end

    message = "Created #{saved_objects} features." unless error

    [object, error, message]
  end

  # build geoJSON for a feature collection
  def self.build_geojson(results)
    json_hash = {}

    # this doesn't change
    json_hash[:crs] = { type: 'name', properties: { name: 'EPSG:4326' } }
    json_hash[:type] = 'FeatureCollection'

    # iterate through results
    json_hash[:features] = []
    results.each do |res|
      json_hash[:features] << build_feature(res)
    end

    # convert to json
    json_data = MultiJson.dump(json_hash)
  end

  # create geoJSON of buildings from their datapoints
  def self.build_geojson_from_datapoints(datapoints)
    json_hash = {}

    # this doesn't change
    json_hash[:crs] = { type: 'name', properties: { name: 'EPSG:4326' } }
    json_hash[:type] = 'FeatureCollection'

    # iterate through results
    json_hash[:features] = []
    datapoints.each do |dp|
      # only datapoints attached to buildings for now
      if dp.building
        res_hash = build_feature(dp.building)
        json_hash[:features] << add_datapoint_to_feature(dp, res_hash)
      end
    end
    # convert to json
    json_data = MultiJson.dump(json_hash)

  end

  # building geoJSON for a single feature
  def self.build_feature(result)
    res_hash = {}
    res_hash[:geometry] = { type: result.geometry.type, coordinates: result.geometry.coordinates }
    res_hash[:type] = 'Feature'
    res_hash[:centroid] = result.geometry.centroid
    res_hash[:properties] = {}
    result.attributes.each do |key, value|
      # convert _id to id
      # remove geometry_id
      if key == '_id'
        res_hash[:properties][:id] = value.to_s
      elsif key == 'project_id'
        res_hash[:properties][:project_id] = value.to_s
      elsif key != 'geometry_id'
        res_hash[:properties][key] = value
      end
    end
    res_hash
  end

  # add datapoint fields to geoJSON properties
  def self.add_datapoint_to_feature(datapoint, res_hash)
    res_hash[:properties][:datapoint] = {}
    datapoint.attributes.each do |key, value|
      if key == '_id'
        res_hash[:properties][:datapoint][:id] = value.to_s
      elsif key != 'project_id' && key != 'building_id'
        if key.include? '_id'
          res_hash[:properties][:datapoint][key] = value.to_s
        else
          res_hash[:properties][:datapoint][key] = value
        end
      end
    end
    res_hash
  end

  # calculate centroid of polygon or multipolygon
  def self.calculate_centroid(coordinates, type)
    points = if type == 'Polygon'
               coordinates[0]
             elsif type == 'Point'
               puts coordinates
               [coordinates]
             else
               # assume multipolygon
               coordinates[0][0]
             end
    logger.info("POINTS: #{points}")
    centroid = points.transpose.map { |c| c.inject { |a, b| a + b }.to_f / c.size }
    logger.info("CENTROID: #{centroid}")

    centroid
  end
end
