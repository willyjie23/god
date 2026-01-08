Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  # 前台捐獻
  resources :donations, only: [ :create ] do
    member do
      get :receipt
      get :receipt_preview
    end
  end

  # 金流
  get  "payments/:donation_id/checkout", to: "payments#checkout",      as: :payment_checkout
  post "payments/notify",                to: "payments#notify",        as: :payment_notify
  post "payments/result",                to: "payments#result",        as: :payment_result
  post "payments/payment_info",          to: "payments#payment_info",  as: :payment_info

  # 健康檢查
  get "up" => "rails/health#show", as: :rails_health_check

  # 首頁
  root "pages#home"
end
