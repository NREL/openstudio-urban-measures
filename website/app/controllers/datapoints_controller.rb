class DatapointsController < ApplicationController
  load_and_authorize_resource
  before_action :set_datapoint, only: [:show, :edit, :update, :destroy, :instance_workflow, :download_file, :delete_file]

  # GET /datapoints
  # GET /datapoints.json
  def index
    page = params[:page] ? params[:page] : 1
    @datapoints = Datapoint.all.page(page)
  end

  # GET /datapoints/1
  # GET /datapoints/1.json
  def show

  end

  # GET /datapoints/new
  def new
    @datapoint = Datapoint.new
    @datapoint.building = params[:building]
    @datapoint.project = @datapoint.building.project
    
    # DLM: datapoint should have 0-1 workflows, is this setting @datapoint.workflows?
    @workflows = get_workflows

  end

  # GET /datapoints/1/edit
  def edit
    @workflows = get_workflows

  end

  # POST /datapoints
  # POST /datapoints.json
  def create

    @datapoint = Datapoint.new
    @workflows = get_workflows

    logger.info("DATAPOINT PARAMS: #{datapoint_params.inspect}")

    error = false
    @error_message = ''

    # DLM: does this hook the datapoint up to the project?  should we do the same for building and workflow?
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
        format.html { render action: 'new', :locals => { building: params[:datapoint][:building_id]}  }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /datapoints/1
  # PATCH/PUT /datapoints/1.json
  def update

    logger.info("DATAPOINT PARAMS: #{datapoint_params.inspect}")
    @workflows = get_workflows

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

  # DELETE /datapoints/1
  # DELETE /datapoints/1.json
  def destroy
    @datapoint.destroy
    respond_to do |format|
      format.html { redirect_to datapoints_url }
      format.json { head :no_content }
    end
  end

  # create datapoints for workflow
  # GET /datapoints/1/instance_workflow
  # GET /datapoints/1/instance_workflow.json
  def instance_workflow

    @error_message = ''
    error = false

    result = Workflow.get_clean_hash(@datapoint.workflow)
    building_hash = Workflow.get_clean_hash(@datapoint.building)
    
    region_hash = {}
    if building_hash[:region_source_name] && building_hash[:region_source_ids]
      building_hash[:region_source_ids].each do |region_source_id|
        region = Region.where(source_id: region_source_id, source_name: building_hash[:region_source_name]).first
        region_hash = Workflow.get_clean_hash(region)
      end
    end
    
    project_hash = {}
    if @datapoint.building.project
      project_hash = Workflow.get_clean_hash(@datapoint.building.project)
      
      if region_hash.empty?
        region = @datapoint.building.project.regions.first
        region_hash = Workflow.get_clean_hash(region)
      end
    end    
    
    if result && result[:steps]
      result[:steps].each do |step|
        if step[:arguments]
          step[:arguments].each do |argument|
            name = argument[:name].parameterize.underscore.to_sym
            #puts "name = #{name}"
            
            if name == 'project_id'.to_sym
              argument[:value] = project_hash[:id]
            elsif name == 'project_name'.to_sym
              argument[:value] = project_hash[:name]
            end
            
            value = project_hash[name]
            if value
              #puts "Setting '#{name}' to '#{value}' based on project level properties" 
              argument[:value] = value
            end
            
            if name == 'region_id'.to_sym
              argument[:value] = region_hash[:id]
            elsif name == 'region_name'.to_sym
              argument[:value] = region_hash[:name]              
            end
            
            value = region_hash[name]
            if value
              #puts "Setting '#{name}' to '#{value}' based on region level properties" 
              argument[:value] = value
            end
            
            if name == 'building_id'.to_sym
              argument[:value] = building_hash[:id]
            elsif name == 'building_name'.to_sym
              argument[:value] = building_hash[:name]               
            end
            
            value = building_hash[name]
            if value
              #puts "Setting '#{name}' to '#{value}' based on building level properties" 
              argument[:value] = value
            end
            
            if name == 'datapoint_id'.to_sym
              argument[:value] = @datapoint.id.to_s         
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

  # Get Workflows
  def get_workflows
    @workflows = @datapoint.project.workflows.only(:id)
    if @workflows.empty?
      @workflows = []
    else
      @workflows = @workflows.map(&:id)
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def datapoint_params
    params.require(:datapoint).permit(:file, :project_id, :building_id, :dencity_id, :workflow, :status, :dencity_url, :analysis_id, :timestamp_started,
                                      :timestamp_completed, variable_values: [], results: [])
  end
end
