class AdminController < ApplicationController
  load_and_authorize_resource :class => AdminController
  def index
  end

  def home

  end

  def batch_upload_features
    
    error = false
    message = ''

    # POST
    if params[:commit]
      if params[:geojson_file]
        data = Geometry.read_geojson_file(params[:geojson_file])
        result, error, message = Geometry.create_update_feature(data)
      else
        # data parameter provided
        error = true
        message += "No data parameter provided."
      end  
  
      respond_to do |format|
        if !error
          format.html { redirect_to batch_upload_features_admin_index_path, notice: "Import success! #{message}" }
          format.json { head :no_content }
        else
          format.html { redirect_to batch_upload_features_admin_index_path, :flash => { :error => "Error: #{message}" } }
          format.json { render json: { error: message }, status: :unprocessable_entity }
        end
      end
    end

  end

  def backup_database
    logger.info params
    write_and_send_data
  end

  def restore_database
    uploaded_file = params[:file]
    if uploaded_file
      reload_database(uploaded_file)
      redirect_to admin_index_path, notice: "Dropped and Reloaded Database with #{uploaded_file.original_filename}"
    else
      redirect_to admin_index_path, notice: 'No file selected'
    end
  end

  def clear_database
    success_1 = false
    success_2 = false

    logger.info "Working directory is #{Dir.pwd} and I am #{`whoami`}"

    `mongo openstudio_urban_modeling_dev --eval "db.dropDatabase();"`
    if $?.exitstatus == 0
      success_1 = true
    end

    # call_rake 'routes' #'db:mongoid:create_indexes'
    # if $?.exitstatus == 0
    #   success_2 = true
    # end

    if success_1 # && success_2
      redirect_to admin_index_path, notice: 'Database deleted successfully.'
    else
      logger.info "Error deleting mongo database: #{success_1}, #{success_2}"
      redirect_to admin_index_path, notice: 'Error deleting database.'
    end
  end

  private

  def reload_database(database_file)
    success = false

    extract_dir = "/tmp/#{Time.now.to_i}"
    FileUtils.mkdir_p(extract_dir)

    resp = `tar xvzf #{database_file.tempfile.path} -C #{extract_dir}`
    if $?.exitstatus == 0
      logger.info 'Successfully extracted uploaded database dump'

      `mongo openstudio_urban_modeling_dev --eval "db.dropDatabase();"`
      if $?.exitstatus == 0
        `mongorestore -d openstudio_urban_modeling_dev #{extract_dir}/openstudio_urban_modeling_dev`
        if $?.exitstatus == 0
          logger.info 'Restored mongo database'
          success = true
        else
          logger.info 'Error trying to reload mongo database'
        end
      end
    end

    success
  end

  def write_and_send_data(file_prefix = 'mongodump')
    success = false

    time_stamp = Time.now.to_i
    dump_dir = "/tmp/#{file_prefix}_#{time_stamp}"
    FileUtils.mkdir_p(dump_dir)

    resp = `mongodump --db openstudio_urban_modeling_dev --out #{dump_dir}`

    if $?.exitstatus == 0
      output_file = "/tmp/#{file_prefix}_#{time_stamp}.tar.gz"
      resp_2 = `tar czf #{output_file} -C #{dump_dir} openstudio_urban_modeling_dev`
      if $?.exitstatus == 0
        success = true
      end
    end

    if File.exist?(output_file)
      send_data File.open(output_file).read, filename: File.basename(output_file), type: 'application/targz; header=present', disposition: 'attachment'
      success = true
    else
      fail 'could not create dump'
    end

    success
  end

end
