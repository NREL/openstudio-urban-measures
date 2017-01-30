class ScenariosController < ApplicationController
  load_and_authorize_resource
  before_action :set_scenario, only: [:show, :edit, :update, :destroy]

  # GET /scenarios
  # GET /scenarios.json
  def index
    #page = params[:page] ? params[:page] : 1
    #@scenarios = Scenario.all.page(page)
    
    @scenarios = Scenario.all
  end

  # GET /scenarios/1
  # GET /scenarios/1.json
  def show

  end

  # GET /scenarios/new
  def new
    @scenario = Scenario.new
    @project_id = params[:project_id] ? params[:project_id] : nil
    @scenario.project = @project_id
    @bld_workflows = Workflow.where(project_id: @project_id, feature_type: 'Building')
    @bld_list = @bld_workflows.map(&:id)
    @ds_workflows = Workflow.where(project_id: @project_id, feature_type: 'District System')
    @ds_list = @ds_workflows.map(&:id)
    if @bld_workflows.count < 1
      @bld_options = []
    else
      @bld_options = OptionSet.in(workflow_id: @bld_list).map{ |n| [n.name, n.id.to_s]}
    end
    if @ds_workflows.count < 1
      @ds_options = []
    else
      @ds_options = OptionSet.in(workflow_id: @ds_list).map{ |n| [n.name, n.id.to_s]}
    end

    @features = Feature.where(project_id: @project_id).in(type: ['Building', 'District System'])
  end

  # GET /scenarios/1/edit
  def edit
    @bld_workflows = Workflow.where(project_id: @scenario.project_id, feature_type: 'Building')
    @bld_list = @bld_workflows.map(&:id)
    @ds_workflows = Workflow.where(project_id: @scenario.project_id, feature_type: 'District System')
    @ds_list = @ds_workflows.map(&:id)
    if @bld_workflows.count < 1
      @bld_options = []
    else
      @bld_options = OptionSet.in(workflow_id: @bld_list).map{ |n| [n.name, n.id.to_s]}
    end
    if @ds_workflows.count < 1
      @ds_options = []
    else
      @ds_options = OptionSet.in(workflow_id: @ds_list).map{ |n| [n.name, n.id.to_s]}
    end
    @features = Feature.where(project_id: @scenario.project_id).in(type: ['Building', 'District System'])
    @datapoints = @scenario.datapoints
  end

  # POST /scenarios
  # POST /scenarios.json
  def create
    @scenario = Scenario.new

    logger.info("scenario PARAMS: #{params}")

    error = false
    @error_message = ''

    if params[:project_id] && !params[:project_id].nil?
      @project_id = params[:project_id]
      @scenario.project_id = @project_id

    else
      error = true
      @error_message += 'No project ID provided.'
    end

    unless error
      
      @scenario.name = params[:name]
     
      # create datapoints here (feature + optionSet)
      datapoints = []
      feature_options = params.select { |key, value| key.to_s.match(/^feature_\d+/) }
      feature_options.each do |feature, option|
        feature = feature.gsub("feature_", "")
        d = Datapoint.find_or_create_by(feature_id: feature, option_set_id: option)
        d.project_id = @project_id
        d.save!
        datapoints << d
      end
      @scenario.datapoints = datapoints
      @scenario.save
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @scenario, notice: 'Scenario was successfully created.' }
        format.json { render action: 'show', status: :created, location: @scenario }
      else
        flash[:error] = @error_message
        format.html { render action: 'edit' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /scenarios/1
  # PATCH/PUT /scenarios/1.json
  def update
    error = false
    @error_message = ''
    
    @scenario.name = params[:name]

    # redo datapoint associations in case of changes (don't modify datapoints, create new ones instead in case used somewhere else)
    datapoints = []
    feature_options = params.select { |key, value| key.to_s.match(/^feature_\d+/) }
    feature_options.each do |feature, option|
      feature = feature.gsub("feature_", "")
      d = Datapoint.find_or_create_by(feature_id: feature, option_set_id: option)
      d.project_id = @scenario.project.id
      d.save!
      datapoints << d
    end
    @scenario.datapoints = datapoints
    @scenario.save
   
    respond_to do |format|
      if !error
        format.html { redirect_to @scenario, notice: 'Scenario was successfully updated.' }
        format.json { render action: 'show', status: :created, location: @scenario }
      else
        flash[:error] = @error_message
        format.html { render action: 'new'}
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /scenarios/1
  # DELETE /scenarios/1.json
  def destroy
    @scenario.destroy
    respond_to do |format|
      format.html { redirect_to scenarios_url }
      format.json { head :no_content }
    end
  end

  # GET all datapoints associated with a scenario
  # For GEOJSON, return as geojson object (like workflow_buildings api)
  def datapoints
    @scenario = Scenario.find(params[:scenario_id])   
    @datapoints = @scenario.datapoints  
    @json_data = Geometry.build_geojson_from_datapoints(@datapoints)
File.open('E:\openstudio-urban-measures\json_data.json', 'w') {|f| f.puts @json_data}
    respond_to do |format|
      format.html {render action: 'datapoints'} # todo: rename results
      format.json {render json: @json_data, status: :ok}
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_scenario
      @scenario = Scenario.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def scenario_params
      params[:scenario]
    end
end
