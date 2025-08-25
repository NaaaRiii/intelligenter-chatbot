Rails.application.routes.draw do
  # Sidekiq Web UI (開発環境のみ)
  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end

  post "/graphql", to: "graphql#execute"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # チャット画面
  get 'chat', to: 'chat#index'
  get 'chat/:conversation_id', to: 'chat#index', as: :conversation_chat
  post 'chat', to: 'chat#create_message'
  
  # RESTful API v1
  namespace :api do
    namespace :v1 do
      resources :conversations do
        resources :messages
        resources :analyses, only: %i[index show] do
          collection do
            post :trigger
          end
        end
      end
      resources :users, only: %i[show update]
    end
  end

  # デモページ
  get 'demo/components', to: 'demo#components'

  # faviconリクエストは204で無視
  get '/favicon.ico', to: proc { [204, {}, []] }

  # Defines the root path route ("/")
  root "chat#index"
end
