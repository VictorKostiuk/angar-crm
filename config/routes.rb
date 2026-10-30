Rails.application.routes.draw do
  resource :session
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # The header's search across bikes, clients and order numbers (D69).
  get "search", to: "search#index"

  resources :clients do
    resources :bikes, only: %i[ new create ]
    # The client's ID photos (D67); index is the rental form's "on file" box.
    resources :documents, only: %i[ index create destroy ], controller: "client_documents"
    get :search, on: :collection
  end
  resources :bikes, only: %i[ index show update destroy ] do
    resources :photos, only: %i[ create destroy ], controller: "bike_photos"
  end

  resources :services, only: %i[ index create update destroy ] do
    get :search, on: :collection
  end
  resources :parts, only: %i[ index create update destroy ] do
    get :search, on: :collection
  end
  resources :suppliers, only: %i[ index create update destroy ]
  get "stock", to: "stock#index"
  resources :sales, only: %i[ index new create ]
  # A short job entered and closed in one form from Майстерня (D71).
  resources :quick_services, only: %i[ new create ]
  # A rental's own PATCH already means "bike returned", so the renter's ID
  # photos get their own nested resource rather than a branch inside it.
  resources :rentals, only: %i[ index new create update ] do
    resources :documents, only: %i[ create destroy ], controller: "rental_documents"
  end
  resources :rental_bikes, only: %i[ create update ] do
    delete "photos/:photo_id", to: "rental_bikes#destroy_photo", as: :photo, on: :member
  end
  resources :stock_movements, only: :create
  resources :expenses, only: %i[ index create update destroy ]
  resources :categories, only: %i[ new create ]

  # Telegram delivers bot updates here (D62). Secret-checked, no session.
  post "telegram/webhook", to: "telegram/webhooks#create", as: :telegram_webhook

  # Booking calendar (D61). A booking is an Order in «Запис», so creating one
  # lives here but everything after that is the order's own page.
  resources :bookings, only: %i[ index new create ] do
    get :slots, on: :collection
  end
  resource :booking_settings, only: :show
  resource :working_hours, only: :update
  resources :maintenance_types, only: %i[ create update destroy ]
  resources :schedule_exceptions, only: %i[ create destroy ]
  resources :booking_problems, only: %i[ create update destroy ]

  resources :orders, only: %i[ index new create show update ] do
    resource :arrival, only: :update, controller: "order_arrivals"
    resource :status, only: %i[ edit update ], controller: "order_statuses"
    resource :payment, only: %i[ edit update ], controller: "order_payments"
    resource :closure, only: %i[ edit update ], controller: "order_closures"
    resource :cancellation, only: %i[ edit update ], controller: "order_cancellations"
    # POST sends the same text to the client through the Telegram bot (D64).
    resource :ready_message, only: %i[ show create ], controller: "order_ready_messages"
    resource :approval_message, only: :show, controller: "order_approval_messages"

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
  get "finances", to: "finances#index"
  get "statistics", to: "statistics#index"

  # Defines the root path route ("/")
  root "workshop#index"
end
