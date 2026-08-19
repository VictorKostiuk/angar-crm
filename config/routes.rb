Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :clients do
    resources :bikes, only: %i[ new create ]
    get :search, on: :collection
  end
  resources :bikes, only: %i[ index update destroy ]

  resources :services, only: %i[ index create update destroy ] do
    get :search, on: :collection
  end
  resources :parts, only: %i[ index create update destroy ] do
    get :search, on: :collection
  end
  resources :suppliers, only: %i[ index create update destroy ]
  resources :expenses, only: %i[ index create update destroy ]
  resources :categories, only: %i[ new create ]

  resources :orders, only: %i[ index new create show update ] do
    resource :status, only: %i[ edit update ], controller: "order_statuses"
    resource :payment, only: %i[ edit update ], controller: "order_payments"
    resource :closure, only: %i[ edit update ], controller: "order_closures"
    resource :cancellation, only: %i[ edit update ], controller: "order_cancellations"

    resources :order_works, only: %i[ new create update destroy ]
    resources :order_parts, only: %i[ new create update destroy ]
    resources :photos, only: %i[ create destroy ], controller: "order_photos"
  end

  patch "workshop/:id/approve", to: "workshop#approve", as: :approve_workshop_order

  resources :users, only: %i[ index create update ]
  resources :discounts, only: %i[ index create update destroy ]
  # Singleton: one shop, one header ticker.
  resource :announcement, only: %i[ edit update ]
  resources :mechanics, only: %i[ index show ] do
    resources :payroll_payouts, only: %i[ new create ]
  end
  get "reports", to: "reports#index"
  get "finances", to: "finances#index"
  get "statistics", to: "statistics#index"

  # Defines the root path route ("/")
  root "workshop#index"
end
