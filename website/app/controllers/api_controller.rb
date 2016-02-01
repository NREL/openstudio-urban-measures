# API controller
class ApiController < ApplicationController

# import
# POST api/batch_upload (New and Update)
def batch_upload

    error = false
    error_message = ''
    saved_structures = 0
    total_count = 0

    # get json data (data param)
    if params[:data]

      # check that crs -> properties -> name == EPSG:4326 (if not, don't upload)
      # TODO: allow longer version of coordinate name
      if params[:data][:crs][:properties][:name] != 'EPSG:4326'
        error = true
        error_message += 'Cannot upload coordinate systems other than EPSG:4326.'

      else
        features = params[:data][:features] ? params[:data][:features] : []
        total_count = features.count
        # import items in the features array
        features.each do |item|
         
          if item[:properties]
            properties = item[:properties]
          else
            properties = nil
            error = true
            error_message += "Missing properties for data item."
          end

          unless properties.nil?
          
            # TODO: use 'type' to determine which type this is (building, region, taxlot, or district_system) 
            # TODO: probably don't need to store 'type' in each model, but must export it back out 

            # BUILDING
            if properties[:bldg_fid] && properties[:bldg_fid] != 'null'
            	# ID provided?
            	if properties[:id] && properties[:id] != 'null'
              	@structure = Building.find_or_create_by(id: properties[:id])
              else
               	# TODO: find_or_create by source_id & source_name 
               	@structure = Building.find_or_create_by(bldg_fid: properties[:bldg_fid])
              end 	
              @structure.type = 'building'
            # TAXLOT
            elsif properties[:lot_fid] && properties[:lot_fid] != 'null'
            	# ID provided?
            	if properties[:id] && properties[:id] != 'null'
            		@structure = Taxlot.find_or_create_by(id: properties[:id])
            	else
            		# TODO: find_or_create by source_id & source_name 
              	@structure = Taxlot.find_or_create_by(lot_fid: properties[:lot_fid])
              end
              @structure.type = 'taxlot'
            end
            # TODO: add region and district_system
            
            properties.each do |key, value|
              if value != 'null'
                @structure[key] = value
              end
            end

            # geojson fields are under geometry
            if item[:geometry]
              geometry = item[:geometry]
              if @structure.geometry.nil?
                @geometry = Geometry.new

                # set association
                association = @structure.class.name.downcase
                # TODO: there's got to be a better way to do this
                if association == 'building'
                	@geometry.building = @structure
                elsif association == 'taxlot'
                	@geometry.taxlot = @structure
                end
                # TODO: add region and district_system
              else
                @geometry = @structure.geometry
              end

              @geometry.type = geometry[:type]
              @geometry.coordinates = geometry[:coordinates]
              
              if @geometry.save!
                saved_structures += 1
              else
                error = true
                error_message += "Could not process: #{@geometry.errors}."
              end
            else
              error = true
              error_message += "Missing geometry for data item."
            end
          end
        end
      end
    else
      # analysis does not belong to user
      error = true
      error_message << "No data parameter provided."
     
    end  
   
    logger.info("SAVED STRUCTURES: #{saved_structures}")

    respond_to do |format|
      if !error
        format.json { render json: "Created #{saved_structures} entries from #{total_count} uploaded.", status: :created, location: buildings_url }
      else
        format.json { render json: { error: error_message }, status: :unprocessable_entity }
      end
    end
  end

  # POST /api/export
  def export

  	# params:
  	# types: array of types to export

  	# for now, choose what types to export only
  	@possible_types = ['all', 'building', 'district system', 'region', 'taxlot']

  	# TODO: allow query (same as on search page) to export data

  	@types = Array.new
  	if params[:types] 
  		params[:types].each do |type|
  			if @possible_types.include? type
  				@types << type
  			end
  		end
  	else
  		@types << 'all'
  	end

  	if @types.include? 'all'
  		@possible_types.delete('all')
  		@types = @possible_types
  	end

  	# retrieve each type
  	@results = []
  	if @types.include? 'building'
  		@results = @results + Building.all.includes(:geometry)
  	end
  	if @types.include? 'taxlot'
  		@results = @results + Taxlot.all.includes(:geometry)
  	end
  	if @types.include? 'region'
  		@results = @results + Region.all.includes(:geometry)
  	end
  	if @types.include? 'district system'
  		@results = @results + DistrictSystem.all.includes(:geometry)
  	end

  	json_data = Geometry.build_geojson(@results)

  	respond_to do |format|
  		format.json { render json: json_data }
  	end

  end

  # POST search
  def search
  	# TODO: finish this
  	# TODO: allow picking multiple types

    @types = ['all', 'building', 'district system', 'region', 'taxlot']
   
    @results = nil

    @bldg_fid = nil
    @distance = nil
    @prox_type = 'building'
    @region_id = nil
    @region_type = 'building'

    # Process POST
    if params[:commit]

      if params[:commit] == 'Proximity Search'
        @bldg_fid = params[:bldg_fid]
        @distance = params[:distance].empty? ? '500' : params[:distance]
        @prox_type = params[:prox_type].empty? ? 'building' : params[:prox_type]

        bldg = Structure.find_by(bldg_fid: @bldg_fid)
        coords = bldg.geometry.coordinates
        # TODO: This doesn't work
        # TODO: include prox_type
        @results = Structure.geo_near(coords).max_distance(@distance)
        logger("RESULTS: #{@results.count}")

      elsif params[:commit] == 'Region Search'
        @region_id = params[:region_id].empty? ? '1' : params[:region_id]
        @region_type = params[:region_type].empty? ? 'building' : params[:region_type]
        # TODO: simple region_id search?
        if @region_type == 'all'
          @results = Structure.where(region_id: @region_id)
        else
          @results = Structure.where(region_id: @region_id, type: @region_type)
        end
      end
    end

    respond_to do |format|
      format.json { render json: { results: @results } }
    	format.html { render 'api/search' }  
    end
  end

end
