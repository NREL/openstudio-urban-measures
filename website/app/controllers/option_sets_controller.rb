class OptionSetsController < ApplicationController
  load_and_authorize_resource
  before_action :set_option_set, only: [:show, :edit, :update, :destroy]

  # GET /option_sets
  # GET /option_sets.json
  def index
    page = params[:page] ? params[:page] : 1
    @option_sets = OptionSet.all.page(page)
  end

  # GET /option_sets/1
  # GET /option_sets/1.json
  def show
     @datapoints = Datapoint.where(option_set_id: @option_set.id)
  end

  # GET /option_sets/new
  def new
    @option_set = OptionSet.new
    @project_id = params[:project_id] ? params[:project_id] : nil
    @workflow_id = params[:workflow_id] ? params[:workflow_id] : nil
    @option_set.project = @project_id
    @option_set.workflow = @workflow_id
  end

  # GET /option_sets/1/edit
  def edit
    @workflows = @option_set.project.workflows
  end

  # POST /option_sets
  # POST /option_sets.json
  def create
    @option_set = OptionSet.new

    logger.info("OPTION SET PARAMS: #{params}")

    error = false
    @error_message = ''

    if params[:project_id] && !params[:project_id].nil?
      @project_id = params[:project_id]
    else
      error = true
      @error_message += 'No project ID provided.'
    end

    unless error
      if params[:workflow_id] && !params[:workflow_id].nil?
        @option_set.workflow_id = params[:workflow_id]
        @option_set.project_id = @project_id
        @option_set.name = params[:name]
        @option_set.save
      else
        error = true
        @error_message += 'No workflow selected.'
      end
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @option_set, notice: 'OptionSet was successfully created.' }
        format.json { render action: 'show', status: :created, location: @option_set }
      else
        flash[:error] = @error_message
        format.html { render action: 'edit' }
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /option_sets/1
  # PATCH/PUT /option_sets/1.json
  def update
    error = false
    @error_message = ''

    if params[:workflow_id] && !params[:workflow_id].nil?
      @option_set.workflow_id = params[:workflow_id]
      @option_set.name = params[:name]
      @option_set.save
    else
      error = true
      @error_message += 'No workflow selected.'
    end

    respond_to do |format|
      if !error
        format.html { redirect_to @option_set, notice: 'OptionSet was successfully updated.' }
        format.json { render action: 'show', status: :created, location: @option_set }
      else
        flash[:error] = @error_message
        format.html { render action: 'new'}
        format.json { render json: { error: @error_message }, status: :unprocessable_entity }
      end
    end

  end

  # DELETE /option_sets/1
  # DELETE /option_sets/1.json
  def destroy
    @option_set.destroy
    respond_to do |format|
      format.html { redirect_to option_sets_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_option_set
      @option_set = OptionSet.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def option_set_params
      params[:option_set]
    end
end
