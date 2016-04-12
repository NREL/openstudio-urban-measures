class DistrictSystemsController < ApplicationController
  load_and_authorize_resource
  before_action :set_district_system, only: [:show, :edit, :update, :destroy]

  # GET /district_systems
  # GET /district_systems.json
  def index
    page = params[:page] ? params[:page] : 1
    @district_systems = DistrictSystem.all.page(page)
    respond_to do |format|
      format.html {}
      format.json { render json: Geometry.build_geojson(@district_systems) }
    end
  end

  # GET /district_systems/1
  # GET /district_systems/1.json
  def show
    respond_to do |format|
      format.html {}
      format.json { render json: Geometry.build_feature(@district_system) }
    end
  end

  # GET /district_systems/new
  def new
    @district_system = DistrictSystem.new
    @project_id = params[:project_id] ? params[:project_id] : nil
  end

  # GET /district_systems/1/edit
  def edit
  end

  # POST /district_systems
  # POST /district_systems.json
  def create
    @district_system = DistrictSystem.new
    error = false
    @error_message = ''

    if params[:project_id] && !params[:project_id].nil?
      @project_id = params[:project_id]
    else
      error = true
      @error_message += 'No project ID provided.'
    end

    unless error
      if params[:geojson_file]
        data = Geometry.read_geojson_file(params[:geojson_file])
        if data.nil?
          error = true
          @error_message += 'No data to process'
        else
          @district_system, error, @error_message = Geometry.create_update_feature(data, @project_id, @district_system)
        end
      else
        error = true
        @error_message += 'No file was uploaded'
      end
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @district_system, notice: 'District System was successfully created.' }
        format.json { render action: 'show', status: :created, location: @district_system }
      else
        flash[:error] = error_message
        format.html { render action: 'new' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /district_systems/1
  # PATCH/PUT /district_systems/1.json
  def update
    error = false
    @error_message = ''
    if params[:geojson_file]
      data = Geometry.read_geojson_file(params[:geojson_file])
      if data.nil?
        error = true
        @error_message += 'No data to process'
      else
        @district_system, error, @error_message = Geometry.create_update_feature(data, @district_system.project.id.to_s, @district_system)
      end
    else
      error = true
      @error_message += 'No file was uploaded'
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @district_system, notice: 'District System was successfully updated.' }
        format.json { head :no_content }
      else
        flash[:error] = @error_message
        format.html { render action: 'edit' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /district_systems/1
  # DELETE /district_systems/1.json
  def destroy
    @district_system.destroy
    respond_to do |format|
      format.html { redirect_to district_systems_url }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_district_system
    @district_system = DistrictSystem.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def district_system_params
    params[:district_system]
  end
end
