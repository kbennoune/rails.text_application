Rails.application.routes.draw do
  text_application_host = Rails.application.config.x.allowed_text_application_host

  scope 'auth/:provider' do
    [ :google, :facebook ].each do |provider|
      match 'callback', action: 'create', controller: "#{provider}_sessions", via: [:get, :post], constraints: {provider: provider}
    end
  end

  match 'auth/failure', to: redirect('/'), via: [:get, :post]

  get 'sessions/new', to: 'sessions#new'
  get 'sessions/destroy', to: 'sessions#destroy'
  delete 'logout', to: 'sessions#destroy'

  namespace :bandwidth_endpoints, module: 'bandwidth_endpoints' do
    resources :mms, only: :create do
      post :callback, on: :collection
    end
  end

  # FOR SMS APP
  resources :sms_links, path: 's', only: [:show] do
    get ':additional_param/:phone_number_id', on: :member, action: :show
    get ':additional_param', on: :member, action: :show, constraints: { additional_param: /[a-zA-Z\-!]+/ }
    get ':phone_number_id', on: :member, action: :show#, constraints: { phone_number_id: /\d+/ }
  end

  resources :sms_invites, path: 'i/:business_id/:secure_code', only: [:index]

  require 'sidekiq/web'
  require 'sidekiq/cron/web'

  namespace 'api', module: 'data_api' do
    scope ':business_id' do
      resources :people
      resources :groups
      resources :channels
      resources :messages
    end

    resource :current_person
    resource :sessions
    resource :request_authentication
    resource :request_subscription_verification
    resource :subscriptions
  end
end
