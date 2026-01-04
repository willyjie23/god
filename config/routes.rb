Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  # 前台捐獻
  resources :donations, only: [ :create ]

  # 健康檢查
  get "up" => "rails/health#show", as: :rails_health_check

  # 首頁
  root "pages#home"
end
