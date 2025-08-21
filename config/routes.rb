Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # デモページ
  get 'demo/components', to: 'demo#components'

  # Defines the root path route ("/")
  # root "articles#index"
end
