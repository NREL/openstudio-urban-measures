Rails.application.routes.draw do
  resources :scenarios
  # apipie
  root 'admin#home'
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
  resources :datapoints
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

    collection do
      get :home
      match 'batch_upload_features' => 'admin#batch_upload_features', :via => [:get, :post]
    end
  end

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
