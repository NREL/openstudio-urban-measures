class DatapointsController < ApplicationController
  load_and_authorize_resource
  before_action :set_datapoint, only: [:show, :edit, :update, :instance_workflow, :destroy, :download_file, :delete_file]

  # GET /datapoints
  # GET /datapoints.json
  def index
    #page = params[:page] ? params[:page] : 1
    #@datapoints = Datapoint.all.page(page)
    
    @datapoints = Datapoint.all
  end

  # GET /datapoints/1
  # GET /datapoints/1.json
  def show

  end

  # GET /datapoints/new
  def new
    @datapoint = Datapoint.new
    @datapoint.feature = params[:feature]
    @datapoint.project = @datapoint.feature.project
    
    @option_sets = get_option_sets

  end

  # GET /datapoints/1/edit
  def edit

  end

  # POST /datapoints
  # POST /datapoints.json
  def create

    @datapoint = Datapoint.new
    @option_sets = get_option_sets

    logger.info("DATAPOINT PARAMS: #{params.inspect}")

    error = false
    @error_message = ''

    if params[:datapoint][:project_id] && !params[:datapoint][:project_id].nil?
      @project_id = params[:datapoint][:project_id]
    else
      error = true
      @error_message += 'No project ID provided.'
    end

    unless error
      the_file = params[:datapoint][:file] ? params[:datapoint][:file] : nil
      params[:datapoint] = params[:datapoint].except(:file)
      @datapoint, error, @error_message = Datapoint.create_update_datapoint(params[:datapoint], @datapoint, @project_id)
    end

    unless error
      if the_file && the_file.class.name == 'ActionDispatch::Http::UploadedFile'
        @datapoint, error, @error_message = Datapoint.add_datapoint_file(the_file, the_file.original_filename, @datapoint)
      end
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @datapoint, notice: 'Datapoint was successfully created.' }
        format.json { render action: 'show', status: :created, location: @datapoint }
      else
        flash[:error] = @error_message
        format.html { render action: 'new', :locals => { feature: params[:datapoint][:feature_id]}  }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /datapoints/1
  # PATCH/PUT /datapoints/1.json
  def update

    logger.info("DATAPOINT PARAMS: #{params.inspect}")
    @option_sets = get_option_sets

    error = false
    @error_message = ''

    if params[:datapoint][:project_id] && !params[:datapoint][:project_id].nil?
      @project_id = params[:datapoint][:project_id]
    else
      error = true
      @error_message += 'No project ID provided.'
    end

    unless error
      the_file = params[:datapoint][:file] ? params[:datapoint][:file] : nil
      params[:datapoint] = params[:datapoint].except(:file)
      @datapoint, error, @error_message = Datapoint.create_update_datapoint(params[:datapoint], @datapoint, @project_id)
    end

    unless error
      if the_file && the_file.class.name == 'ActionDispatch::Http::UploadedFile'
        @datapoint, error, @error_message = Datapoint.add_datapoint_file(the_file, the_file.original_filename, @datapoint)
      end
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @datapoint, notice: 'Datapoint was successfully updated.' }
        format.json { head :no_content }
      else
        flash[:error] = @error_message
        format.html { render action: 'edit' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # get workflow for datapoint
  # GET /datapoints/1/instance_workflow
  # GET /datapoints/1/instance_workflow.json
  def instance_workflow

    @error_message = ''
    error = false

    result = Workflow.get_clean_hash(@datapoint.option_set)
   
    feature_hash = {}
    project_hash = {}
    scenario_hash = {} # only for district systems
    
    if @datapoint.feature
      feature_hash = Workflow.get_clean_hash(@datapoint.feature)
    
      if @datapoint.feature.type == 'District System'
        if @datapoint.scenario.size == 1
          scenario_hash = Workflow.get_clean_hash(@datapoint.scenario[0])
        elsif @datapoint.scenario.size == 0
          # DLM: error?
        else
          # DLM: error?
        end
      end
    end
    
    if @datapoint.project
      project_hash = Workflow.get_clean_hash(@datapoint.project)
    end    
    
    if result && result[:steps]
      result[:steps].each do |step|
        if step[:arguments]
          arguments = step[:arguments]
          arguments.each_key do |name|
            name = name.parameterize.underscore.to_sym
            #puts "name = #{name}"
            
            if name == 'project_id'.to_sym
              arguments[name] = project_hash[:id]
            elsif name == 'project_name'.to_sym
              arguments[name] = project_hash[:name]
            end
            
            value = project_hash[name]
            if value
              #puts "Setting '#{name}' to '#{value}' based on project level properties" 
              arguments[name] = value
            end
          
            if name == 'scenario_id'.to_sym
              arguments[name] = scenario_hash[:id]
            elsif name == 'scenario_name'.to_sym
              arguments[name] = scenario_hash[:name]
            end
            
            value = scenario_hash[name]
            if value
              #puts "Setting '#{name}' to '#{value}' based on scenario level properties" 
              arguments[name] = value
            end
            
            if name == 'feature_id'.to_sym
              arguments[name] = feature_hash[:id]
            elsif name == 'feature_name'.to_sym
              arguments[name] = feature_hash[:name]               
            end
            
            value = feature_hash[name]
            if value
              #puts "Setting '#{name}' to '#{value}' based on building level properties" 
              arguments[name] = value
            end
            
            if name == 'datapoint_id'.to_sym
              arguments[name] = @datapoint.id.to_s         
            end
          end
        end
      end
    end

    respond_to do |format|
      if !error
        format.html { render json: result }
        format.json { render json: result }
      else
        format.html { render json: { error: @error_message }, status: :unprocessable_entity }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /datapoints/1
  # DELETE /datapoints/1.json
  def destroy
    @datapoint.destroy
    respond_to do |format|
      format.html { redirect_to datapoints_url }
      format.json { head :no_content }
    end
  end

  # download a related datapoint file
  def download_file
    file = @datapoint.datapoint_files.find(params[:file_id])
    raise 'file not found in database' unless file

    file_data = Datapoint.get_file_data(file)
    if file_data
      send_data file_data, filename: File.basename(file.uri), type: 'application/octet-stream; header=present', disposition: 'attachment'
    else
      raise 'file not found in database'
    end
  end

  # delete datapoint file
  def delete_file
    file = @datapoint.datapoint_files.find(params[:file_id])
    raise 'file not found in database' unless file

    if File.exist?("#{Rails.root}#{file.uri}")
      File.delete("#{Rails.root}#{file.uri}")
    end
    df = @datapoint.datapoint_files.find(params[:file_id])
    df.delete

    respond_to do |format|
      format.html { redirect_to @datapoint }
      format.json { render json: 'File deleted', status: :ok }
    end

  end

  private

    
  # Use callbacks to share common setup or constraints between actions.
  def set_datapoint
    @datapoint = Datapoint.find(params[:id])
    logger.info("@datapoint = #{@datapoint}")
  end

  # Get Option Sets
  def get_option_sets
    @option_sets = @datapoint.project.option_sets.only(:id)
    if @option_sets.empty?
      @option_sets = []
    else
      @option_sets = @option_sets.map(&:id)
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def datapoint_params
    params.require(:datapoint).permit(:file, :project_id, :feature_id, :option_set_id, :timestamp_started, :timestamp_completed, :status, results: {} )
  end

end
