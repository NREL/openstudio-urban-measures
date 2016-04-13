class DatapointsController < ApplicationController
  load_and_authorize_resource
  before_action :set_datapoint, only: [:show, :edit, :update, :destroy]
  before_action :get_workflows, only: [:new, :edit]

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
  end

  # GET /datapoints/1/edit
  def edit
  end

  # POST /datapoints
  # POST /datapoints.json
  def create
    @datapoint = Datapoint.new(datapoint_params)
    # TODO: generate instance workflow

    respond_to do |format|
      if @datapoint.save
        format.html { redirect_to @datapoint, notice: 'Datapoint was successfully created.' }
        format.json { render action: 'show', status: :created, location: @datapoint }
      else
        format.html { render action: 'new' }
        format.json { render json: @datapoint.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /datapoints/1
  # PATCH/PUT /datapoints/1.json
  def update
    # TODO: generate instance workflow

    respond_to do |format|
      if @datapoint.update(datapoint_params)
        format.html { redirect_to @datapoint, notice: 'Datapoint was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @datapoint.errors, status: :unprocessable_entity }
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
  def instance_workflow
    @error_message = ''
    error = false

    result = get_clean_hash(@datapoint.workflow)
    building_hash = get_clean_hash(@datapoint.building)

    region_hash = {}
    if @datapoint.building.region_id
      region = Region.find(@datapoint.building.region_id)
      region_hash = get_clean_hash(region)
    end
    
    project_hash = {}
    if @datapoint.building.project
      project_hash = get_clean_hash(@datapoint.building.project)
    end    
    
    if result && result[:steps]
      result[:steps].each do |step|
        if step[:arguments]
          step[:arguments].each do |argument|
            name = argument[:name].parameterize.underscore.to_sym
            #puts "name = #{name}"
            
            value = project_hash[name]
            if value
              #puts "Setting '#{name}' to '#{value}' based on project level properties" 
              argument[:value] = value
            end
            
            value = region_hash[name]
            if value
              #puts "Setting '#{name}' to '#{value}' based on region level properties" 
              argument[:value] = value
            end
            
            value = building_hash[name]
            if value
              #puts "Setting '#{name}' to '#{value}' based on building level properties" 
              argument[:value] = value
            end
          end
        end
      end
    end
    
    # DLM: how to get result into the json return?
    
    respond_to do |format|
      if !error
        format.html { render json: result }
        format.json { render json: result }
      else
        format.html { render action: 'show' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  private

  # DLM: this should be a common utility method, put it in models?
  # Ideally this would recursively clean the object, seems like this should exist?
  def get_clean_hash(object)
    result = {}
    if object
      object.attributes.each do |key, value|
        # convert object ids to strings
        if key == '_id'
          result[:id] = value.to_s
        elsif value.class == BSON::ObjectId
          result[key.parameterize.underscore.to_sym] = value.to_s
        else
          result[key.parameterize.underscore.to_sym] = value
        end
      end
    end
    return result
  end
  
  # Use callbacks to share common setup or constraints between actions.
  def set_datapoint
    @datapoint = Datapoint.find(params[:id])
  end

  # Get Workflows
  def get_workflows
    @workflows = Workflow.where(type: 'template').only(:id).map(&:id)
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def datapoint_params
    params.require(:datapoint).permit(:building_id, :dencity_id, :template_workflow, :instance_workflow, :dencity_url, :analysis_id, :timestamp_started,
                                      :timestamp_completed, variable_values: [], results: [])
  end
end
