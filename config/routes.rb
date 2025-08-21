Rails.application.routes.draw do
  post "/graphql", to: "graphql#execute"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # チャット画面
  get 'chat', to: 'chat#index'
  get 'chat/:conversation_id', to: 'chat#index', as: :conversation_chat
  
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

  # Defines the root path route ("/")
  root "chat#index"
end
