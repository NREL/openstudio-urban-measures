# Geometry class
class Geometry
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :type, type: String
  field :coordinates, type: Array  # format order for coordinates is: [long, lat]

  # Validation

  # Relations
  has_one :building, autosave: true, dependent: :destroy
  has_one :taxlot, autosave: true, dependent: :destroy
  has_one :district_system, autosave: true, dependent: :destroy
  has_one :region, autosave: true, dependent: :destroy

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

  # this method is to be used to 
  def self.create_update_feature(data, object)

    error = false
    error_message = ''

    # TODO: may have to read in file

    if data[:crs][:properties][:name] != 'EPSG:4326'
      error = true
      error_message += 'Cannot upload coordinate systems other than EPSG:4326.'

    else
      features = data[:features] ? data[:features] : []
      total_count = features.count
      # there should only be 1 item in the features array
      item = features.first
       
      if item[:properties]
        properties = item[:properties]
      else
        properties = nil
        error = true
        error_message += "Missing properties for data item."
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
            # TODO: there's got to be a better way to do this
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

          unless @geometry.save!
            error = true
            error_message += "Could not process: #{@geometry.errors}."
          end
        end
      end
    end

    return object, error, error_message
  end

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

  private
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

end
