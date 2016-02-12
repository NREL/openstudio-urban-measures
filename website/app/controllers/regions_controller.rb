class RegionsController < ApplicationController
  load_and_authorize_resource
  before_action :set_region, only: [:show, :edit, :update, :destroy]

  # GET /regions
  # GET /regions.json
  def index
    page = params[:page] ? params[:page] : 1
    @regions = Region.all.page(page)
    respond_to do |format|
      format.html {}
      format.json{ render json: Geometry.build_geojson(@regions)}
    end
  end

  # GET /regions/1
  # GET /regions/1.json
  def show
    respond_to do |format|
      format.html {}
      format.json{ render json: Geometry.build_feature(@region)}
    end
  end

  # GET /regions/new
  def new
    @region = Region.new
  end

  # GET /regions/1/edit
  def edit
  end

  # POST /regions
  # POST /regions.json
  def create
    @region = Region.new

    if params[:geojson_file]
      data = Geometry.read_geojson_file(params[:geojson_file])
      if data.nil?
        error = true
        error_message += 'No data to process'
      else
        @region, error, @error_message = Geometry.create_update_feature(data, @region)
      end
    else
      error = true
      error_message += 'No file was uploaded'
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @region, notice: 'Region was successfully created.' }
        format.json { render action: 'show', status: :created, location: @region }
      else
        format.html { render action: 'new' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /regions/1
  # PATCH/PUT /regions/1.json
  def update
    if params[:geojson_file]
      data = Geometry.read_geojson_file(params[:geojson_file])
      if data.nil?
        error = true
        error += 'No data to process'
      else
        @region, error, @error_message = Geometry.create_update_feature(data, @region)
      end
    else
      error = true
      error_message += 'No file was uploaded'
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @region, notice: 'Region was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /regions/1
  # DELETE /regions/1.json
  def destroy
    @region.destroy
    respond_to do |format|
      format.html { redirect_to regions_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_region
      @region = Region.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def region_params
      params[:region]
    end
end
