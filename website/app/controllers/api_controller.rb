# API controller
class ApiController < ApplicationController

  # import
  # POST api/batch_upload (New and Update)
  def batch_upload

    error = false
    message = ''

    # get json data (data param)
    if params[:data]
      # sent last result, doesn't mean anything here
      result, error, message = Geometry.create_update_feature(params[:data])
    else
      # data parameter provided
      error = true
      message += "No data parameter provided."
    end  
  
    respond_to do |format|
      if !error
        format.json { render json: message, status: :created, location: buildings_url }
      else
        format.json { render json: { error: message }, status: :unprocessable_entity }
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
        @distance = params[:distance].empty? ? 500 : params[:distance].to_i
        @prox_types = params[:prox_types].empty? ? @prox_types : params[:prox_types]

        @types = Array.new
    
        @prox_types.each do |type|
          if @possible_types.include? type.capitalize
            @types << type.capitalize
          end
        end

        if @types.include? 'All'
          @possible_types.delete('All')
          @types = @possible_types
        end

        bldgs = Building.where(bldg_fid: @bldg_fid)
        unless bldgs.count == 0
          bldg = bldgs.first
          centroid = bldg.geometry.centroid

          @geo_results = Geometry.includes(:building, :region, :district_system, :taxlot).geo_near(centroid).max_distance(@distance)
          logger.info("HEY!! #{@geo_results.count}")

          @geo_results.each do |res|
            if res.building
              @results << res.building
            elsif res.taxlot
              @results << res.taxlot
            elsif res.region
              @results << res.region
            elsif res.district_system
              @results << res.district_system
            end
          end
          
        end

      elsif params[:commit] == 'Region Search'

        @region_id = params[:region_id].empty? ? '1' : params[:region_id]
        @region_types = params[:region_types].empty? ? @region_types : params[:region_types]

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

          #model = type.constantize
          #@results = @results + model.where(region_id: @region_id)

          # TODO: this doesn't work yet
          # retrieve region and get geometry
          region = Region.where(region_id: @region_id).first

          #@results = Geometry.where(centroid: {
          #  $geoWithin: {
          #    $geometry: {
          #      type:  region.geometry.type,
          #      coordinates: region.geometry.coordinates
          #    }
          #  }
          #})
          @results = nil
        end

      end
    end

    respond_to do |format|
      format.json { render json: { results: @results } }
    	format.html { render 'api/search' }  
    end
  end

  # POST /api/workflow.json
  def workflow

    error = false
    error_message = ''
    created_flag = false
    @workflow = nil
    
    if params[:workflow]

      data = params[:workflow]

      # update or create
      if data[:id]
        workflows = Workflow.where(id: data[:id])
        if workflows.count > 0
          @workflow = workflows.first
          logger.info("WORKFLOW FOUND: UPDATING")
        else
          error = true
          error_message = "No workflows match ID #{data[:id]}.  Cannot update."
          logger.info("WORKFLOW NOT FOUND!")
        end
      else
        @workflow = Workflow.new
        created_flag = true
        logger.info("NEW WORKFLOW: CREATING")
      end
      unless error
        @workflow, error, error_message = Workflow.create_update_workflow(data, @workflow)
      end
    else
      error = true
      error_message += "No workflow parameter provided."
    end

    respond_to do |format|
        if error
          format.json { render json: { error: error_messages, workflow: @workflow }, status: :unprocessable_entity }
        else
          if created_flag
            status = :created
          else
            status = :ok
          end
          format.json { render 'workflows/show', status: status, location: workflows_url(@workflow) }
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
