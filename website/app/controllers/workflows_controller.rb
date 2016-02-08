class WorkflowsController < ApplicationController
  load_and_authorize_resource
  before_action :set_workflow, only: [:show, :edit, :update, :destroy]

  # GET /workflows
  # GET /workflows.json
  def index
    @workflows = Workflow.all
  end

  # GET /workflows/1
  # GET /workflows/1.json
  def show
  end

  # GET /workflows/new
  def new
    @workflow = Workflow.new
  end

  # GET /workflows/1/edit
  def edit
  end

  # POST /workflows
  # POST /workflows.json
  def create
    @workflow = Workflow.new
    
    error = false
    error_message = ''

    if params[:json_file] && params[:json_file].class.name == 'ActionDispatch::Http::UploadedFile'
      # TODO: move this into create_update function?
      data = read_json_file(params[:json_file])
      if data.nil?
        error = true
        error_message += 'No data to process'
      else
        @workflow, error, error_message = Workflow.create_update_workflow(data, @workflow)
      end
    else
      error = true
      error_message += 'No file was uploaded'
    end

    unless error
      if params[:zip_file] && params[:zip_file].class.name == 'ActionDispatch::Http::UploadedFile'
        zip_file = params[:zip_file]
        logger.info("****FILE DATA: #{zip_file.inspect}")
        @workflow, error, error_message = Workflow.add_workflow_file(zip_file, @workflow)
      
      end
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @workflow, notice: 'Workflow was successfully created.' }
        format.json { render action: 'show', status: :created, location: @workflow }
      else
        format.html { render action: 'new' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /workflows/1
  # PATCH/PUT /workflows/1.json
  def update
    error = false
    error_message = ''
    
    if params[:json_file] && params[:json_file].class.name == 'ActionDispatch::Http::UploadedFile'
      # TODO: move this into create_update function?
      data = read_json_file(params[:json_file])
      if data.nil?
        error = true
        error += 'No data to process'
      else
        @workflow, error, @error_message = Workflow.create_update_workflow(data, @workflow)
      end
    else
      error = true
      error_message += 'No file was uploaded'
    end

    # TODO zipfile
    if params[:zip_file] && params[:zip_file].class.name == 'ActionDispatch::Http::UploadedFile'
      zip_file = params[:zip_file]
      @workflow, error, error_message = Workflow.add_workflow_file(zip_file, @workflow)
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @workflow, notice: 'Workflow was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /workflows/1
  # DELETE /workflows/1.json
  def destroy
    @workflow.destroy
    respond_to do |format|
      format.html { redirect_to workflows_url }
      format.json { head :no_content }
    end
  end

  # download a related workflowfile
  def download_zipfile
    file = @workflow.workflow_file
    fail 'file not found in database' unless file

    file_data = get_file_data(file)
    if file_data
      send_data file_data, filename: File.basename(file.uri), type: 'application/octet-stream; header=present', disposition: 'attachment'
    else
      fail 'file not found in database'
    end
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_workflow
      @workflow = Workflow.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def workflow_params
      params[:workflow]
    end

    # Read in Workflow JSON
    # TODO: add error handling here and return gracefully
    def read_json_file(file_data)
      if file_data.class.to_s == 'Hash'
         data = file_data
      elsif file_data.respond_to?(:read)
        file = file_data.read
        data = MultiJson.load(file, :symbolize_keys => true)
      elsif file_data.respond_to?(:path)
        file = File.read(file_data.path)
        data = MultiJson.load(file, :symbolize_keys => true)
      else
        logger.error "Bad file_data: #{file_data.class.name}: #{file_data.inspect}"
        data = nil
      end
      return data
    end

    # download a file
    def get_file_data(file)
      begin
        file_data = nil
        fail 'File not stored on the server' unless File.exist?("#{Rails.root}#{file.uri}")
        file_data = File.read("#{Rails.root}#{file.uri}")

        fail "Could not find file to download #{file.uri}" if file_data.nil?
      rescue => e
        flash[:notice] = "Could not find file to download #{file.uri}. #{e.message}"
        logger.error "Could not find file to download #{file.uri}. #{e.message}"
        redirect_to(:back)
      end

      file_data
    end
end
