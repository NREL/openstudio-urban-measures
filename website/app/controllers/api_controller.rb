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
      # data parameter provided
      error = true
      error_message += "No data parameter provided."
     
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
  	@possible_types = ['All', 'Building', 'District System', 'Region', 'Taxlot']

  	# TODO: allow query (same as on search page) to export data

  	@types = Array.new
  	if params[:types] 
  		params[:types].each do |type|
  			if @possible_types.include? type.capitalize
  				@types << type.capitalize
  			end
  		end
  	else
  		@types << 'All'
  	end

  	if @types.include? 'All'
  		@possible_types.delete('All')
  		@types = @possible_types
  	end

  	# retrieve each type
  	@results = []
    @types.each do |type|
      type = type.gsub(" ", "")
      model = type.constantize
      @results = @results + model.all.includes(:geometry)
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

    @possible_types = ['All', 'Building', 'District System', 'Region', 'Taxlot']
   
    @results = []

    @bldg_fid = nil
    @distance = nil
    @prox_types = ['Building']
    @region_id = nil
    @region_types = ['Building']

    # Process POST
    if params[:commit]

      if params[:commit] == 'Proximity Search'
        @bldg_fid = params[:bldg_fid]
        @distance = params[:distance].empty? ? '500' : params[:distance]
        @prox_type = params[:prox_type].empty? ? @prox_types : params[:prox_type]

        bldg = Building.find_by(bldg_fid: @bldg_fid)
        coords = bldg.geometry.coordinates
        # TODO: This doesn't work
        # TODO: include prox_type & refactor
        @results = Building.geo_near(coords).max_distance(@distance)
        logger("RESULTS: #{@results.count}")

      elsif params[:commit] == 'Region Search'
        @region_id = params[:region_id].empty? ? '1' : params[:region_id]
        @region_types = params[:region_type].empty? ? @region_types : params[:region_type]

        # figure out what types
        @types = Array.new
    
        @region_types.each do |type|
          if @possible_types.include? type.capitalize
            @types << type.capitalize
          end
        end

        if @types.include? 'All'
          @possible_types.delete('All')
          @types = @possible_types
        end

        # Iterate through array and get all results
        @types.each do |type|
          # remove spaces (for district system)
          type = type.gsub(" ", "")

          model = type.constantize

          @results = @results + model.where(region_id: @region_id)
        end

      end
    end

    respond_to do |format|
      format.json { render json: { results: @results } }
    	format.html { render 'api/search' }  
    end
  end

  def workflow

    error = false
    error_message = ''
    
    if params[:workflow]

      data = params[:workflow]

      # update or create
      if data[:id]
        wf = Workflow.find(data[:id])
      else
        wf = Workflow.new
      end

      wf, error, error_message = Workflow.create_update_workflow(data, wf)

    else
      error = true
      error_message += "No workflow parameter provided."
    end

    respond_to do |format|
      if !error
        format.json { render json: "Workflow Imported", status: :created, location: workflows_url }
      else
        format.json { render json: { error: error_message }, status: :unprocessable_entity }
      end
    end

  end

  # POST /api/workflow_file.json
  def workflow_file
    
    # expects workflow_id and file params

    error = false
    error_messages = []
    clean_params = file_params

    @workflow = Workflow.find(clean_params[:workflow_id])

    if !@workflow
      error = true
      error_messages << "Workflow #{@workflow.id} could not be found."
    else
      basic_path = WORKFLOW_FILES_BASIC_PATH
      # save to file_path:
      if clean_params[:file_data] && clean_params[:file_data][:file_name]
        file_name = clean_params[:file_data][:file_name]
        file = @workflow.workflow_files.find_by_file_name(file_name)
        if file
          error = true
          error_messages << "File #{file_name} already exists. Delete the file first and reupload."
        else
          file_uri = "#{basic_path}#{@workflow.id}/#{file_name}"
          FileUtils.mkpath("#{Rails.root}#{basic_path}") unless Dir.exist?("#{Rails.root}#{basic_path}")
          Dir.mkdir("#{Rails.root}#{basic_path}#{@workflow.id}/") unless Dir.exist?("#{Rails.root}#{basic_path}#{@workflow.id}/")

          the_file = File.open("#{Rails.root}/#{file_uri}", 'wb') do |f|
            f.write(Base64.strict_decode64(clean_params[:file_data][:file]))
          end
          @wf = WorkflowFile.add_from_path(file_uri)
          @workflow.workflow_files << @wf
          @workflow.save
        end
      else
        error = true
        error_messages << 'No file data to save.'
      end
    end
    respond_to do |format|
      if error
        format.json { render json: { error: error_messages, related_file: @wf }, status: :unprocessable_entity }
      else
        format.json { render 'workflow_file', status: :created, location: workflow_url(@workflow) }
      end
    end
  end

  private

  def file_params
    params.require(:workflow_id)
    params.permit(:workflow_id, file_data: [:file_name, :file])
  end

end
