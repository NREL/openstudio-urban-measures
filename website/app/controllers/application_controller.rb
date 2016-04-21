class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  protect_from_forgery with: :null_session, if: proc { |c| c.request.format == 'application/json' }

  rescue_from CanCan::AccessDenied do |exception|
	 		respond_to do |format|
	    format.html { redirect_to root_url, alert: exception.message }
	    format.json { render json: { error: 'You do not have permission to access this resource.'}, :status => :forbidden }
	  end
  end
end
