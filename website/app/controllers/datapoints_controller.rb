class DatapointsController < ApplicationController
  load_and_authorize_resource
  before_action :set_datapoint, only: [:show, :edit, :update, :destroy]

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
    logger.info("PARAMS: #{params}")
    @datapoint.building = params[:building]
    logger.info("hey! #{@datapoint.building}")
    @datapoint.project = @datapoint.building.project
    logger.info("hey2! #{@datapoint.project}")
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

    logger.info("DATAPOINT PARAMS: #{datapoint_params.inspect}")

    error = false
    @error_message = ''

    if params[:datapoint][:project_id] && !params[:datapoint][:project_id].nil?
      @project_id = params[:datapoint][:project_id]
    else
      error = true
      @error_message += 'No project ID provided.'
    end

    unless error
      # TODO: eventually check datapoint param
      @datapoint, error, @error_message = Datapoint.create_update_datapoint(params[:datapoint], @datapoint, @project_id)
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

    error = false
    @error_message = ''

    if params[:datapoint][:project_id] && !params[:datapoint][:project_id].nil?
      @project_id = params[:datapoint][:project_id]
    else
      error = true
      @error_message += 'No project ID provided.'
    end

    unless error
      @datapoint, error, @error_message = Datapoint.create_update_datapoint(params[:datapoint], @datapoint, @project_id)
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

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_datapoint
    @datapoint = Datapoint.find(params[:id])
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
    params.require(:datapoint).permit(:project_id, :building_id, :dencity_id, :workflow, :status, :dencity_url, :analysis_id, :timestamp_started,
                                      :timestamp_completed, variable_values: [], results: [], )
  end
end
