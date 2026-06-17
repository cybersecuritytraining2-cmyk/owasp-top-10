Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    # Authentication
    post "login",  to: "sessions#create"
    post "logout", to: "sessions#destroy"

    # The signed-in customer's own dashboard (profile, balance, card)
    get "me", to: "accounts#me"

    # Open a new account (savings, vacation fund, …) for the signed-in customer
    post "accounts", to: "accounts#create"

    # Transaction history for an account
    get "accounts/:account_number/transactions", to: "accounts#transactions"

    # Move money to another customer by account number
    post "transfers", to: "transfers#create"

    # Pay down a credit card balance
    post "cards/pay", to: "cards#pay"

    # Operations console — staff only.
    namespace :admin do
      get  "logs",              to: "dashboard#logs"
      get  "transactions",      to: "dashboard#transactions"
      get  "users",             to: "dashboard#users"
      post "users/:id/block",   to: "dashboard#block"
      post "users/:id/unblock", to: "dashboard#unblock"
    end
  end
end
