Rails.application.routes.draw do
  namespace :admin do
    resource :yandex_market_settings do
      member do
        match :export_files
        get :run_export
      end
    end
  end
end
