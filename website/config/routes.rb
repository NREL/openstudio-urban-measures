Rails.application.routes.draw do
  
  resources :projects do
    member do
      match 'batch_upload_features' => 'projects#batch_upload_features', :via => [:get, :post]
    end
  end

  # apipie
  root 'projects#index'
  match 'search' => 'api#search', :via => [:get, :post]

  devise_for :users
  resources :users
  devise_scope :user do
    get '/login' => 'devise/sessions#new'
    get '/logout' => 'devise/sessions#destroy'
  end

  resources :scenarios do
    get 'datapoints'
  end
  resources :features
  resources :option_sets
  resources :datapoints do
    member do
      get 'instance_workflow'
      get 'download_file'
      get 'delete_file'
    end
  end
  resources :workflows do
    member do
      get 'download_zipfile'
      #get 'delete_datapoints'
    end
  end

  scope '/api' do
    post 'batch_upload' => 'api#batch_upload'
    post 'workflow' => 'api#workflow'
    post 'workflow_file' => 'api#workflow_file'
    match 'search' => 'api#search', :via => [:get, :post]
    post 'export' => 'api#export'
    post 'project_search' => 'api#project_search'
    post 'datapoint' => 'api#datapoint'
    post 'retrieve_datapoint' => 'api#retrieve_datapoint'
    get 'retrieve_workflow_file' => 'api#retrieve_workflow_file'
    get 'workflow_buildings' => 'api#workflow_buildings'
    post 'datapoint_file' => 'api#datapoint_file'
    get 'retrieve_datapoint_file' => 'api#retrieve_datapoint_file'
    get 'delete_datapoint_file' => 'api#delete_datapoint_file'
  end

  match 'admin/backup_database' => 'admin#backup_database', :via => :get
  match 'admin/restore_database' => 'admin#restore_database', :via => :post
  match 'admin/purge_database' => 'admin#purge_database', :via => :get
  match 'admin/clear_data' => 'admin#clear_data', :via => :get

  resources :admin, only: [:index] do
    get :backup_database
    post :restore_database
    get :purge_database
    get :clear_data
  end

end
