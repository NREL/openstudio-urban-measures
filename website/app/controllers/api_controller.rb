# API controller
class ApiController < ApplicationController
  before_filter :check_auth, except: [:search]

  # import
  # POST api/batch_upload (New and Update)
  def batch_upload
    error = false
    message = ''

    # need project_id
    if params[:project_id]
      project_id = params[:project_id]
      @project = Project.find(project_id)
      # get json data (data param)
      if params[:data]
        # sent last result, doesn't mean anything here
        result, error, message = Geometry.create_update_feature(params[:data], project_id)
      else
        # data parameter provided
        error = true
        message += 'No data parameter provided.'
      end
    else
      error = true
      message += 'No project_id parameter provided.'
    end

    respond_to do |format|
      if !error
        format.json { render json: message, status: :created, location: project_url(@project) }
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
        # DLM: capitalize turns 'District System' into 'District system'
        #@types << type.capitalize if @possible_types.include? type.capitalize
        @types << type if @possible_types.include? type
      end
    else
      @types << 'All'
    end

    if @types.include? 'All'
      @possible_types.delete('All')
      @types = @possible_types
    end

    # TODO: error handling if project_id is missing
    project_id = params[:project_id]

    # retrieve each type
    @results = Feature.where(project_id: project_id).in(type: @types).includes(:geometry)

    json_data = Geometry.build_geojson(@results)

    respond_to do |format|
      format.json { render json: json_data }
    end
  end

  # POST project_search
  def project_search
    error = false
    message = ''

    # DLM: can I make this so it will match anything if params[:name] is empty?
    name = (params[:name] && !params[:name].empty?) ? params[:name] : /./
    unless error

      page = params[:page] ? params[:page] : 1

      @results = []
      res = Project.where(name: name)

      res.each do |r|
        @results << r
      end

      @total_count = @results.count
      if request.format == 'application/json'
        json_results = []
        @results.each do |result|
          json_result = {}
          result.attributes.each do |key, value|
            # convert object ids to strings
            if key == '_id' 
              json_result[:id] = value.to_s
            elsif key == 'user_id'
              json_result[:user_id] = value.to_s
            else
              json_result[key] = value
            end
          end
          json_results << json_result
        end
        @results = json_results
      else
        # pagination
        @results = Kaminari.paginate_array(@results.to_a).page(page)
      end
      
    end

    respond_to do |format|
      format.json { render json: @results }
      format.html { render 'api/search' }
    end
  end
  
  # POST search
  def search
    error = false
    message = ''

    if params[:project_id]
      @project = Project.find(params[:project_id])
    else
      error = true
      message += 'Project ID was not provided.'
    end

    unless error

      page = params[:page] ? params[:page] : 1
      @possible_types = ['All', 'Building', 'District System', 'Region', 'Taxlot']
      @regions = @project.features.where(type: 'Region').only(:id).asc(:id).map { |x| [x.id.to_s] }
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

          @types = @feature_types

          if @types.include? 'All'
            @types = @possible_types.dup
            @types.delete('All')
          end

          res = Feature.where(project_id: @project.id, source_id: @source_id, source_name: @source_name).in(type: @types)
          @results = []
          res.each do |r|
            @results << r.geometry
          end

          @total_count = @results.count
          if request.format != 'application/json'
            # pagination
            @results = Kaminari.paginate_array(@results.to_a).page(page)
          end

        # GEO NEAR SEARCH
        elsif params[:commit] == 'Proximity Search'
          @feature_id = (params[:feature_id] && !params[:feature_id].empty?) ? params[:feature_id] : ''
          @distance = (params[:distance] && !params[:distance].nil?) ? params[:distance].to_i : 100
          @proximity_feature_types = (params[:proximity_feature_types] && !params[:proximity_feature_types].empty?) ? params[:proximity_feature_types] : @proximity_feature_types

          @types = @proximity_feature_types

          if @types.include? 'All'
            @types = @possible_types.dup
            @types.delete('All')
          end

          features = @project.features.where(id: @feature_id)
          unless features.count == 0
            feature = features.first
            centroid = feature.geometry.centroid

            query = Mongoid::Criteria.new(Geometry)
            query = query.where(project_id: @project.id)

            # TODO: figure out how to restrict to only the 4 types (and not other geojson features)
            # unless @types.count == 4
            #   # add the feature types to the query 
            #   # TODO: this is an 'and' but should work like an 'or'... FIX IT
            #   @types.each do |type|
            #     field = type.downcase.tr(' ', '_') + '_id'
            #     query = query.exists(field.to_sym => true)
            #   end
            # end
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
          @types = @region_feature_types

          if @types.include? 'All'
            @types = @possible_types.dup
            @types.delete('All')
          end

          the_region = Feature.find(@region_id)

          # test_coords = [[[[-109.05029296875,41.00477542222949],[-102.06298828125,41.00477542222949],[-102.052001953125,36.99377838872517],[-109.072265625,37.020098201368114],[-109.05029296875,41.00477542222949]]]];

          query = @project.geometries.where('centroid' =>
                                   { '$geoWithin' =>
                                      { '$geometry' =>
                                        { 'type' => the_region.geometry.type,
                                          'coordinates' => the_region.geometry.coordinates
                                        }
                                      }
                                    })

          # TODO: figure out how to restrict to only the 4 types (and not other geojson features)
          # unless @types.count == 4
          #   # add the feature types to the query
          #   @types.each do |type|
          #     field = type.downcase.tr(' ', '_') + '_id'
          #     query = query.exists(field.to_sym => true)
          #   end
          # end

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
    end

    respond_to do |format|
      format.json { render json: json_data }
      format.html { render 'api/search' }
    end
  end

  # POST/GET /api/datapoint.json
  # expects project_id and datapoint params
  def datapoint
    error = false
    error_message = ''
    created_flag = false

    if params[:project_id]
      @project = Project.find(params[:project_id])
    else
      error = false
      error_message = 'Project ID is not provided.'
    end

    unless error 
      if params[:datapoint]
        data = params[:datapoint]
        # update or create
        if data[:id]
          datapoints = @project.datapoints.where(id: data[:id])
          if datapoints.count > 0
            @datapoint = datapoints.first
            logger.info('DATAPOINT FOUND: UPDATING')
          else
            error = true
            error_message = "No datapoints match ID #{data[:id]} for project #{@project.id.to_s}.  Cannot update."
            logger.info('DATAPOINT NOT FOUND!')
          end
        else
          # DLM: should also have an option set and building id
          @datapoint = Datapoint.new
          created_flag = true
          logger.info('NEW DATAPOINT: CREATING')
        end
        unless error
          # DLM: should also have a workflow and building id
          @datapoint, error, error_message = Datapoint.create_update_datapoint(data, @datapoint, @project.id)
        end
      else
        error = true
        error_message += 'No datapoint parameter provided.'
      end
     
    end

    respond_to do |format|
      if error
        format.json { render json: { error: error_message, datapoint: @datapoint}, status: :unprocessable_entity }
      else
        status = if created_flag
                   :created
                 else
                   :ok
                 end
        format.json { render 'datapoints/show', status: status, location: datapoints_url(@datapoint) }
      end
    end
  end

  # POST /api/retrieve_datapoint.json
  def retrieve_datapoint
    error = false
    error_message = ''
    created_flag = false

    if params[:project_id]
      @project = Project.find(params[:project_id])
    else
      error = false
      error_message = 'Project ID is not provided.'
    end

    unless error

      # GET
      if params[:option_set_id] && params[:feature_id]
        @datapoint = @project.datapoints.find_or_create_by(option_set_id: params[:option_set_id], feature_id: params[:feature_id])
      else
        error = true
        error_message += 'Missing parameters to retrieve datapoint.'  
      end
   
    end

    respond_to do |format|
      if error
        format.json { render json: { error: error_message, datapoint: @datapoint}, status: :unprocessable_entity }
      else
        status = if created_flag
                   :created
                 else
                   :ok
                 end
        format.json { render 'datapoints/show', status: status, location: datapoints_url(@datapoint) }
      end
    end
  end

  # POST /api/workflow.json
  def workflow
    error = false
    error_message = ''
    created_flag = false
    @workflow = nil

    if params[:project_id]
      @project = Project.find(params[:project_id])
    else
      error = false
      error_message = 'Project ID is not provided.'
    end

    unless error

      if params[:workflow]

        data = params[:workflow]

        # update or create
        if data[:id]
          workflows = @project.workflows.where(id: data[:id])
          if workflows.count > 0
            @workflow = workflows.first
            logger.info('WORKFLOW FOUND: UPDATING')
          else
            error = true
            error_message = "No workflows match ID #{data[:id]} for project #{@project.id.to_s}.  Cannot update."
            logger.info('WORKFLOW NOT FOUND!')
          end
        else
          @workflow = Workflow.new
          created_flag = true
          logger.info('NEW WORKFLOW: CREATING')
        end
        unless error
          @workflow, error, error_message = Workflow.create_update_workflow(data, @workflow, @project.id, params[:name])
        end
      else
        error = true
        error_message += 'No workflow parameter provided.'
      end
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

  # GET workflow_buildings
  def workflow_buildings
    # params are project_id and workflow_id
    error = false
    error_messages = []

    if params[:project_id]
      @project = Project.find(params[:project_id])
      if params[:workflow_id]
        @wf = @project.workflows.where(id: params[:workflow_id]).first
      else
        error = true
        error_messages << "No workflow_id parameter provided."
      end
    else
      error = true
      error_messages << "No project_id parameter provided."
    end
    
    unless error
      @datapoints = @wf.datapoints
      json_data = Geometry.build_geojson_from_datapoints(@datapoints)
    end

    respond_to do |format|
      if error
        format.json { render json: { error: error_messages}, status: :unprocessable_entity}
      else
        format.json { render json: json_data, status: :ok }
      end
    end


  end

  # GET workflow file by workflow_id or datapoint
  def retrieve_workflow_file
    error = false
    error_messages = []

    if params[:datapoint_id]
      @dp = Datapoint.where(id: params[:datapoint_id]).first
      if !@dp.nil? 
        # get workflow through option set
        @wf = @dp.option_set.workflow
      else
        error = true
        error_messages << "No datapoint found matching id: #{params[:datapoint_id]}."
      end
    elsif params[:workflow_id]
      @wf = Workflow.find(params[:workflow_id])
    else
      error = true
      error_messages << "No datapoint_id or workflow_id parameter provided."
    end
    unless error
      if @wf.nil?
        error = true
        error_messages << "No workflow found."
      else
        wf_file = @wf.workflow_file
        if wf_file
          the_file = Workflow.get_file_data(wf_file)
          if the_file
            encoded_file = Base64.strict_encode64(the_file)
            @file_data = {}
            @file_data['file_name'] = wf_file.file_name
            @file_data['file'] = encoded_file

          else
            error = true
            error_messages << 'file not found in database'
          end
        else
          error = true
          error_messages << 'file not found in database'
        end
      end
    end
    respond_to do |format|
      if error
        format.json { render json: { error: error_messages, workflow: @wf }, status: :unprocessable_entity }
      else
        format.json { render json: {file_data: @file_data}, status: :ok }
      end
    end

  end

  # POST /api/datapoint_file.json
  def datapoint_file
    # expects workflow_id and file params
    error = false
    error_messages = []
    clean_params = datapoint_file_params

    @datapoint = Datapoint.find(clean_params[:datapoint_id])

    if !@datapoint
      error = true
      error_messages << "Datapoint #{@datapoint.id} could not be found."
    else
      # save to file_path:
      if clean_params[:file_data] && clean_params[:file_data][:file_name] && clean_params[:file_data][:file]
        filename = clean_params[:file_data][:file_name]
        file = clean_params[:file_data][:file]

        @datapoint, error, error_message = Datapoint.add_datapoint_file(file, filename, @datapoint, true)

      else
        error = true
        error_messages << 'No file data to save.'
      end
    end
    respond_to do |format|
      if error
        format.json { render json: { error: error_message, datapoint: @datapoint }, status: :unprocessable_entity }
      else
        format.json { render 'datapoint_files', status: :created, location: datapoint_url(@datapoint) }
      end
    end
  end

  # GET /api/retrieve_datapoint_file.json
  # retrieve datapoint_file by datapoint_id and file_name
  def retrieve_datapoint_file
    error = false
    error_messages = []

    if params[:datapoint_id]
      @dp = Datapoint.where(id: params[:datapoint_id]).first
      if @dp.nil? 
        error = true
        error_messages << "No datapoint found matching id: #{params[:datapoint_id]}."
      end
    else
      error = true
      error_messages << "No datapoint_id parameter provided."
    end
    unless error
      if params[:file_name]
        @df = @dp.datapoint_files.where(file_name: params[:file_name]).first
        if @df.nil?
          error = true
          error_messages << "No datapoint_file found in database."
        else
          the_file = Workflow.get_file_data(@df)
          if the_file
            encoded_file = Base64.strict_encode64(the_file)
            @file_data = {}
            @file_data['file_name'] = @df.file_name
            @file_data['file'] = encoded_file
          else
            error = true
            error_messages << "No file found."
          end
        end
      else
        error = true
        error_messages << "No file_name parameter provided."
      end
    end
    respond_to do |format|
      if error
        format.json { render json: { error: error_messages, datapoint: @dp }, status: :unprocessable_entity }
      else
        format.json { render json: {file_data: @file_data}, status: :ok }
      end
    end
  end

  # Delete datapoint file by datapoint_id and file_name
  # TODO: make this a delete? (a GET for now)
  def delete_datapoint_file
    error = false
    error_messages = []

    if params[:datapoint_id]
      @dp = Datapoint.where(id: params[:datapoint_id]).first
      if @dp.nil? 
        error = true
        error_messages << "No datapoint found matching id: #{params[:datapoint_id]}."
      end
    else
      error = true
      error_messages << "No datapoint_id parameter provided."
    end
    unless error
      if params[:file_name]
        @df = @dp.datapoint_files.where(file_name: params[:file_name]).first
        if @df.nil?
          error = true
          error_messages << "No datapoint_file found in database."
        else
          if File.exist?("#{Rails.root}#{@df.uri}")
            File.delete("#{Rails.root}#{@df.uri}")
          end
          @df.delete
        end
      else
        error = true
        error_message << "No file_name parameter provided."
      end
    end
    respond_to do |format|
      if error
        format.json { render json: { error: error_messages, datapoint: @dp }, status: :unprocessable_entity }
      else
        format.json { render json: 'file deleted' , status: :ok }
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
      if ['Building', 'District System', 'Region', 'Taxlot'].include? res.feature.type 
        @new_results << res.feature
      end
    end
    @new_results
  end

  # file params
  def file_params
    params.require(:workflow_id)
    params.permit(:workflow_id, file_data: [:file_name, :file])
  end

    def datapoint_file_params
    params.require(:datapoint_id)
    params.permit(:datapoint_id, file_data: [:file_name, :file])
  end
end
