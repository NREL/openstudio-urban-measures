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
      message += 'No data parameter provided.'
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
  # TODO: this isn't super useful anymore...deprecate?
  def export
    # params:
    # types: array of types to export

    # for now, choose what types to export only
    @possible_types = ['All', 'Building', 'District System', 'Region', 'Taxlot']

    # TODO: allow query (same as on search page) to export data

    @types = []
    if params[:types]
      params[:types].each do |type|
        @types << type.capitalize if @possible_types.include? type.capitalize
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
      type = type.delete(' ')
      model = type.constantize
      @results += model.all.includes(:geometry)
    end

    json_data = Geometry.build_geojson(@results)

    respond_to do |format|
      format.json { render json: json_data }
    end
  end

  # POST search
  def search
    error = false
    message = ''

    page = params[:page] ? params[:page] : 1
    @possible_types = ['All', 'Building', 'District System', 'Region', 'Taxlot']
    @regions = Region.all.only(:id).asc(:id).map { |x| [x.id.to_s] }
    @building_id = nil
    @distance = nil
    @proximity_feature_types = ['Building']
    @region_id = nil
    @region_feature_types = ['Building']
    @source_id = nil
    @source_name = nil
    @feature_types = ['Building']
    @results = []
    @is_get = true
    @search_type = 'Proximity'

    # Process POST
    if params[:commit]

      @is_get = false
      if params[:commit] ==  'Search'
        @search_type = 'ID'
        @source_id = (params[:source_id] && !params[:source_id].empty?) ? params[:source_id] : ''
        @source_name = (params[:source_name] && !params[:source_name].empty?) ? params[:source_name] : ''
        @feature_types = (params[:feature_types] && !params[:feature_types].empty?) ? params[:feature_types] : @feature_types

        @types = []

        @feature_types.each do |type|
          @types << type.capitalize if @possible_types.include? type.capitalize
        end

        if @types.include? 'All'
          @types = @possible_types.dup
          @types.delete('All')
        end

        @results = []
        @types.each do |type|
          model = type.tr(' ', '').constantize
          res = model.where(source_id: @source_id, source_name: @source_name)
          # this is weird but it needs to match the other searches
          res.each do |r|
            @results << r.geometry
          end
        end

        @total_count = @results.count
        if request.format != 'application/json'
          # pagination
          @results = Kaminari.paginate_array(@results.to_a).page(page)
        end

      # GEO NEAR SEARCH
      elsif params[:commit] == 'Proximity Search'
        @building_id = (params[:building_id] && !params[:building_id].empty?) ? params[:building_id] : ''
        @distance = (params[:distance] && !params[:distance].nil?) ? params[:distance].to_i : 100
        @proximity_feature_types = (params[:proximity_feature_types] && !params[:proximity_feature_types].empty?) ? params[:proximity_feature_types] : @proximity_feature_types

        @types = []

        @proximity_feature_types.each do |type|
          @types << type.capitalize if @possible_types.include? type.capitalize
        end

        if @types.include? 'All'
          @types = @possible_types.dup
          @types.delete('All')
        end

        bldgs = Building.where(id: @building_id)
        unless bldgs.count == 0
          bldg = bldgs.first
          centroid = bldg.geometry.centroid

          query = Mongoid::Criteria.new(Geometry)
          unless @types.count == 4
            # add the feature types to the query
            @types.each do |type|
              field = type.downcase.tr(' ', '_') + '_id'
              query = query.exists(field.to_sym => true)
            end
          end
          query = query.geo_near(centroid).max_distance(@distance)
          @results = query
          @total_count = @results.count

          if request.format != 'application/json'
            # pagination
            @results = Kaminari.paginate_array(@results.to_a).page(page)
          end
        end

      # GEO WITHIN SEARCH
      elsif params[:commit] == 'Region Search'
        @search_type = 'Region'

        @region_id = (params[:region_id] && params[:region_id].empty?) ? params[:region_id] : @regions.first[0]
        @region_feature_types = (params[:region_feature_types] && !params[:region_feature_types].empty?) ? params[:region_feature_types] : @region_feature_types

        # figure out what types
        @types = []

        @region_feature_types.each do |type|
          @types << type.capitalize if @possible_types.include? type.titleize
        end

        if @types.include? 'All'
          @types = @possible_types.dup
          @types.delete('All')
        end

        the_region = Region.find(@region_id)

        # test_coords = [[[[-109.05029296875,41.00477542222949],[-102.06298828125,41.00477542222949],[-102.052001953125,36.99377838872517],[-109.072265625,37.020098201368114],[-109.05029296875,41.00477542222949]]]];

        query = Geometry.where('centroid' =>
                                 { '$geoWithin' =>
                                    { '$geometry' =>
                                      { 'type' => the_region.geometry.type,
                                        'coordinates' => the_region.geometry.coordinates
                                      }
                                    }
                                  })

        unless @types.count == 4
          # add the feature types to the query
          @types.each do |type|
            field = type.downcase.tr(' ', '_') + '_id'
            query = query.exists(field.to_sym => true)
          end
        end

        @results = query
        @total_count = @results.count
        if request.format != 'application/json'
          # pagination
          @results = @results.page(page)
        end
      end
    end

    # process results into geoJSON for API
    if request.format == 'application/json'
      @new_results = process_search_results
      json_data = Geometry.build_geojson(@new_results)
    end

    respond_to do |format|
      format.json { render json: json_data }
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
          logger.info('WORKFLOW FOUND: UPDATING')
        else
          error = true
          error_message = "No workflows match ID #{data[:id]}.  Cannot update."
          logger.info('WORKFLOW NOT FOUND!')
        end
      else
        @workflow = Workflow.new
        created_flag = true
        logger.info('NEW WORKFLOW: CREATING')
      end
      unless error
        @workflow, error, error_message = Workflow.create_update_workflow(data, @workflow)
      end
    else
      error = true
      error_message += 'No workflow parameter provided.'
    end

    respond_to do |format|
      if error
        format.json { render json: { error: error_message, workflow: @workflow }, status: :unprocessable_entity }
      else
        status = if created_flag
                   :created
                 else
                   :ok
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

  # check authorization
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

  # process search results
  def process_search_results
    # turn geometry results into feature results
    @new_results = []

    @results.each do |res|
      if res.building_id
        @new_results << res.building
      elsif res.taxlot_id
        @new_results << res.taxlot
      elsif res.region_id
        @new_results << res.region
      elsif res.district_system_id
        @new_results << res.district_system
      end
    end
    @new_results
  end

  # file params
  def file_params
    params.require(:workflow_id)
    params.permit(:workflow_id, file_data: [:file_name, :file])
  end
end
