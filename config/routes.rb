Rails.application.routes.draw do
  root "pages#home"
  get "about", to: "pages#about"
  get "up", to: "rails/health#show", as: :rails_health_check

  # Accounts
  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  get "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  resource :password, only: %i[edit update]
  resources :password_resets, only: %i[new create edit update], param: :token
  resources :invitations, only: %i[edit update], param: :token

  # Company workspace
  get "dashboard", to: "dashboard#show"
  resource :my_request, only: %i[show update]
  resources :employees do
    collection do
      get :import, action: :import_form
      post :import
      get :template
    end
    member { post :invite }
  end
  resources :locations, except: :show
  resources :matches, only: %i[index show] do
    collection { post :run }
    member do
      patch :approve
      patch :reject
      patch :reopen
      patch :complete
    end
  end
  resources :team_members, except: :show do
    member { post :resend_invitation }
  end
  resource :company, only: %i[edit update]
  resources :jobs, only: :index do
    collection { patch :describe }
  end
  resources :job_similarities, only: [] do
    member do
      patch :override
      patch :recheck
    end
  end
  get "activity", to: "audit_events#index"

  # Platform owner area: customers + sales outreach
  namespace :admin do
    root "dashboard#show"
    resources :companies, only: %i[index show]
    namespace :outreach do
      root "prospects#index"
      get "lead_sources", to: "lead_sources#show"
      resources :prospects do
        collection do
          get :import, action: :import_form
          post :import
        end
      end
      resources :templates, except: :show
      resources :campaigns, only: %i[new create] do
        collection { post :preview }
      end
      resources :emails, only: %i[index show]
      resources :suppressions, only: %i[index create destroy]
    end
  end

  # JSON API for AI agents doing outreach (see docs/outreach-agent/)
  namespace :api do
    namespace :outreach do
      get "status", to: "status#show"
      get "lead_sources", to: "lead_sources#show"
      get "check", to: "checks#show"
      resources :prospects, only: %i[index show create update]
      resources :templates, only: :index
      resources :emails, only: :index
      resources :campaigns, only: :create
    end
  end

  # Public opt-out link included in every outreach email
  get "unsubscribe/:token", to: "outreach/unsubscribes#show", as: :outreach_unsubscribe
  post "unsubscribe/:token", to: "outreach/unsubscribes#create"
end
