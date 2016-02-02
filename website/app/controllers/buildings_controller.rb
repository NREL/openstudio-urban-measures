class BuildingsController < ApplicationController
  load_and_authorize_resource
  before_action :set_building, only: [:show, :edit, :update, :destroy]

  # GET /buildings
  # GET /buildings.json
  def index
    @buildings = Building.all.includes(:geometry)

    respond_to do |format|
      format.html {}
      format.json{ render json: Geometry.build_geojson(@buildings)}
    end
  end

  # GET /buildings/1
  # GET /buildings/1.json
  def show

    respond_to do |format|
      format.html {}
      format.json{ render json: Geometry.build_geojson([@building])}
    end
  end

  # GET /buildings/new
  def new
    @building = Building.new
  end

  # GET /buildings/1/edit
  def edit
  end

  # POST /buildings
  # POST /buildings.json
  def create
    @building = Building.new

    if params[:geojson_file]
      data = Geometry.read_geojson_file(params[:geojson_file])
      if data.nil?
        error = true
        error_message += 'No data to process'
      else
        @building, error, @error_message = Geometry.create_update_feature(data, @building)
      end
    else
      error = true
      error_message += 'No file was uploaded'
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @building, notice: 'Building was successfully created.' }
        format.json { render action: 'show', status: :created, location: @building }
      else
        format.html { render action: 'new' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /buildings/1
  # PATCH/PUT /buildings/1.json
  def update

    if params[:geojson_file]
      data = Geometry.read_geojson_file(params[:geojson_file])
      if data.nil?
        error = true
        error += 'No data to process'
      else
        @building, error, @error_message = Geometry.create_update_feature(data, @building)
      end
    else
      error = true
      error_message += 'No file was uploaded'
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @building, notice: 'Building was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /buildings/1
  # DELETE /buildings/1.json
  def destroy
    @building.destroy
    respond_to do |format|
      format.html { redirect_to buildings_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_building
      @building = Building.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def building_params
      params[:building]
    end
   
end
