Trailticket::Engine.routes.draw do
  defaults format: :json do
    get "me", to: "me#show"

    resources :tickets, only: %i[index show create update] do
      member do
        post :close
        post :reopen
        get :screenshot
      end
      resources :messages, only: :create
    end
  end
end
