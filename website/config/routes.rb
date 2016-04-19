Rails.application.routes.draw do
  resources :projects do
    member do
      match 'batch_upload_features' => 'projects#batch_upload_features', :via => [:get, :post]
    end
  end


  resources :scenarios
  # apipie
  root 'projects#index'
  match 'search' => 'api#search', :via => [:get, :post]

  devise_for :users
  resources :users

  devise_scope :user do
    get '/login' => 'devise/sessions#new'
    get '/logout' => 'devise/sessions#destroy'
  end

  resources :regions
  resources :district_systems
  resources :taxlots
  resources :buildings
  resources :datapoints do
    member do
      get 'instance_workflow'
    end
  end
  resources :workflows do
    member do
      get 'download_zipfile'
      get 'create_datapoints'
      get 'delete_datapoints'
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
