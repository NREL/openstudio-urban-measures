class TaxlotsController < ApplicationController
  before_action :set_taxlot, only: [:show, :edit, :update, :destroy]

  # GET /taxlots
  # GET /taxlots.json
  def index
    @taxlots = Taxlot.all.includes(:geometry)

    respond_to do |format|
      format.html {}
      format.json{ render json: Geometry.build_geojson(@taxlots)}
    end
  end

  # GET /taxlots/1
  # GET /taxlots/1.json
  def show
    respond_to do |format|
      format.html {}
      format.json{ render json: Geometry.build_geojson([@taxlot])}
    end
  end

  # GET /taxlots/new
  def new
    @taxlot = Taxlot.new
  end

  # GET /taxlots/1/edit
  def edit
  end

  # POST /taxlots
  # POST /taxlots.json
  def create
    @taxlot = Taxlot.new

    if params[:geojson_file]
      data = Geometry.read_geojson_file(params[:geojson_file])
      if data.nil?
        error = true
        error_message += 'No data to process'
      else
        @taxlot, error, @error_message = Geometry.create_update_feature(data, @taxlot)
      end
    else
      error = true
      error_message += 'No file was uploaded'
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @taxlot, notice: 'Taxlot was successfully created.' }
        format.json { render action: 'show', status: :created, location: @taxlot }
      else
        format.html { render action: 'new' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /taxlots/1
  # PATCH/PUT /taxlots/1.json
  def update
    if params[:geojson_file]
      data = Geometry.read_geojson_file(params[:geojson_file])
      if data.nil?
        error = true
        error += 'No data to process'
      else
        @taxlot, error, @error_message = Geometry.create_update_feature(data, @taxlot)
      end
    else
      error = true
      error_message += 'No file was uploaded'
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @taxlot, notice: 'Taxlot was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /taxlots/1
  # DELETE /taxlots/1.json
  def destroy
    @taxlot.destroy
    respond_to do |format|
      format.html { redirect_to taxlots_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_taxlot
      @taxlot = Taxlot.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def taxlot_params
      params[:taxlot]
    end
end
