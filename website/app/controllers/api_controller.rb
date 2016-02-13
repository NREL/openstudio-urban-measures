# API controller
class ApiController < ApplicationController

  before_filter :check_auth, except: [:search]

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
    page = params[:page] ? params[:page] : 1

    @possible_types = ['All', 'Building', 'District System', 'Region', 'Taxlot']
    @regions = Region.all.only(:id, :state_abbr).asc(:state_abbr).map { |x| [x.state_abbr, x.id] }    
    @bldg_id = nil
    @distance = nil
    @prox_types = ['Building']
    @region_id = nil
    @region_types = ['Building']
    @results = []
    @is_get = true
    @search_type = 'proximity'

    # Process POST
    # TODO: for API, will need to check method (post/get)
    # TODO: this won't work as is via JSON api resource
    if params[:commit]

      @is_get = false
      # GEO NEAR SEARCH
      if params[:commit] == 'Proximity Search'
        @bldg_id = params[:bldg_id]
        @distance = params[:distance].empty? ? 500 : params[:distance].to_i
        @prox_types = params[:prox_types].empty? ? @prox_types : params[:prox_types]

        @types = Array.new
    
        @prox_types.each do |type|
          if @possible_types.include? type.capitalize
            @types << type.capitalize
          end
        end
        logger.info("TYPES: #{@types}")

        if @types.include? 'All'
          @types = @possible_types.dup
          @types.delete('All')
        end
        logger.info("TYPES: #{@types}")

        bldgs = Building.where(id: @bldg_id)
        unless bldgs.count == 0
          bldg = bldgs.first
          centroid = bldg.geometry.centroid

          query = Mongoid::Criteria.new(Geometry)
          unless @types.count == 4
            # add the feature types to the query
            @types.each do |type|
              field = type.downcase.gsub(" ", "_") + "_id"
              query = query.exists(field.to_sym => true)
            end
          end
          query = query.geo_near(centroid).max_distance(@distance)
          @results = query
          @total_count = @results.count
          @results = Kaminari.paginate_array(@results.to_a).page(page)

        end

      # GEO WITHIN SEARCH
      elsif params[:commit] == 'Region Search'
        @search_type = 'region'

        @region_id = params[:region_id].empty? ? @regions.first : params[:region_id]
        @region_types = params[:region_types].empty? ? @region_types : params[:region_types]

        # figure out what types
        @types = Array.new
    
        @region_types.each do |type|
          if @possible_types.include? type.titleize
            @types << type.capitalize
          end
        end

        if @types.include? 'All'
          @types = @possible_types.dup
          @types.delete('All')
        end

        the_region = Region.find(@region_id)

        #test_coords = [[[[-109.05029296875,41.00477542222949],[-102.06298828125,41.00477542222949],[-102.052001953125,36.99377838872517],[-109.072265625,37.020098201368114],[-109.05029296875,41.00477542222949]]]];

        query = Geometry.where({"centroid" => 
                                 { "$geoWithin" => 
                                    { "$geometry" => 
                                      { "type" => the_region.geometry.type, 
                                        "coordinates" => the_region.geometry.coordinates
                                      }
                                    }
                                  }
                                })

        unless @types.count == 4
          # add the feature types to the query
          @types.each do |type|
            field = type.downcase.gsub(" ", "_") + "_id"
            query = query.exists(field.to_sym => true)
          end
        end

        #paginate
        query = query.page(page)
        @results = query 
        @total_count = @results.count
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
          format.json { render json: { error: error_message, workflow: @workflow }, status: :unprocessable_entity }
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
      # save to file_path:
      if clean_params[:file_data] && clean_params[:file_data][:file_name]
        filename = clean_params[:file_data][:file_name]
        zip_file = clean_params[:file_data][:file]

        @workflow, error, error_message = Workflow.add_workflow_file(zip_file, filename, @workflow, true)

      else
        error = true
        error_messages << 'No file data to save.'
      end
    end
    respond_to do |format|
      if error
        format.json { render json: { error: error_messages, workflow: @workflow }, status: :unprocessable_entity }
      else
        format.json { render 'workflow_file', status: :created, location: workflow_url(@workflow) }
      end
    end
  end

  private

  def check_auth
    authenticate_or_request_with_http_basic do |username, password|
      begin
        resource = User.find_by(email: username)
       rescue
         respond_to do |format|
           format.json { render json: "No user matching username #{username}", status: :unauthorized }
         end
      else
        sign_in :user, resource if resource.valid_password?(password)
      end
    end
  end


  def file_params
    params.require(:workflow_id)
    params.permit(:workflow_id, file_data: [:file_name, :file])
  end

end
