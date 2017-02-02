class FeaturesController < ApplicationController
  load_and_authorize_resource
  before_action :set_feature, only: [:show, :edit, :update, :destroy]

  # GET /features
  # GET /features.json
  def index
    page = params[:page] ? params[:page] : 1
    @features = Feature.all.page(page)

    respond_to do |format|
      format.html {}
      format.json { render json: Geometry.build_geojson(@features) }
    end
  end

  # GET /features/1
  # GET /features/1.json
  def show
    respond_to do |format|
      format.html {}
      format.json { render json: Geometry.build_feature(@feature) }
    end
  end

  # GET /features/new
  def new
    @feature = Feature.new
    @project_id = params[:project_id] ? params[:project_id] : nil
  end

  # GET /features/1/edit
  def edit
  end

  # POST /features
  # POST /features.json
  def create

    @feature = Feature.new

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
          @feature, error, @error_message = Geometry.create_update_feature(data, @project_id, @feature)
        end
      else
        error = true
        @error_message += 'No file was uploaded'
      end
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @feature, notice: 'Feature was successfully created.' }
        format.json { render action: 'show', status: :created, location: @feature }
      else
        flash[:error] = @error_message
        format.html { render action: 'new' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end

  end

  # PATCH/PUT /features/1
  # PATCH/PUT /features/1.json
  def update
    error = false
    @error_message = ''
    if params[:geojson_file]
      data = Geometry.read_geojson_file(params[:geojson_file])
      if data.nil?
        error = true
        @error_message += 'No data to process'
      else
        @feature, error, @error_message = Geometry.create_update_feature(data, @feature.project.id.to_s, @feature)
      end
    else
      error = true
      @error_message += 'No file was uploaded'
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @feature, notice: 'Feature was successfully updated.' }
        format.json { head :no_content }
      else
        flash[:error] = @error_message
        format.html { render action: 'edit' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /features/1
  # DELETE /features/1.json
  def destroy
    @feature.destroy
    respond_to do |format|
      format.html { redirect_to features_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_feature
      @feature = Feature.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def feature_params
      params[:feature]
    end
end
