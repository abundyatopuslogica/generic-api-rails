GenericApiRails::Engine.routes.draw do
  namespace :generic_api_rails, :path => "/" do
    match '*path' => "base#options", :via => [:options]
  
    namespace "authentication" do 
      get 'facebook' 
      post 'facebook'
      get 'login'
      post 'login'
      get 'signup'
      post 'signup'
      get 'logout'
      post 'logout'
    end

    get    'version'                    => 'misc#version'
    get    'whoami'                     => 'misc#whoami'

    get    '(:namespace/):model/:id'    => 'rest#read',    constraints: { :id => /\d+/, :model => /\D+/ }
    match  '(:namespace/):model/:id'    => 'rest#update',  constraints: { :id => /\d+/, :model => /\D+/ }, via: [:post, :put, :patch]
    delete '(:namespace/):model/:id'    => 'rest#destroy', constraints: { :id => /\d+/, :model => /\D+/ }
    get    '(:namespace/):model'        => 'rest#index',   constraints: { :id => /\d+/, :model => /\D+/ }
    post   '(:namespace/):model'        => 'rest#create',  constraints: { :id => /\d+/, :model => /\D+/ }
  end
end
