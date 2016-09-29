class ProjectsController < ApplicationController
  load_and_authorize_resource
  before_action :set_project, only: [:show, :edit, :update, :destroy, :batch_upload_features]

  # GET /projects
  # GET /projects.json
  def index
    page = params[:page] ? params[:page] : 1
    @projects = Project.all.page(page)
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(project_params)
    @project.user = current_user

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { render action: 'show', status: :created, location: @project }
      else
        format.html { render action: 'new' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1
  # PATCH/PUT /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project.destroy
    respond_to do |format|
      format.html { redirect_to projects_url }
      format.json { head :no_content }
    end
  end

  def batch_upload_features
    error = false
    message = ''

    # POST
    if params[:commit]
      if @project
        if params[:geojson_file]
          data = Geometry.read_geojson_file(params[:geojson_file])
          result, error, message = Geometry.create_update_feature(data, @project.id)
        else
          # data parameter provided
          error = true
          message += 'No data parameter provided.'
        end
      else
        error = true
        message += 'No project id provided.'
      end

      respond_to do |format|
        if !error
          format.html { redirect_to project_path(@project), notice: "Import success! #{message}" }
          format.json { head :no_content }
        else
          format.html { redirect_to batch_upload_features_project_path(@project), flash: { error: "Error: #{message}" } }
          format.json { render json: { error: message }, status: :unprocessable_entity }
        end
      end
    end
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def project_params
      params[:project].permit(:name)
    end
end
