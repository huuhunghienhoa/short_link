Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post :encode, to: "short_urls#encode"
      get "decode/:short_code", to: "short_urls#decode"
    end
  end
end

