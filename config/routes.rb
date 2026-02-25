# frozen_string_literal: true

NanacoApm::Engine.routes.draw do
  root to: 'dashboard#index'

  resources :requests, only: %i[index show], param: :id
  resources :endpoints, only: %i[index show], param: :id
  resources :queries, only: [] do
    collection do
      get :slow
      get :n_plus_one
    end
  end
  resources :sidekiq, only: %i[index] do
    collection do
      get :failed
    end
  end
  resources :system, only: %i[index] do
    collection do
      get :chart_data
    end
  end
  resources :events, only: %i[index create]

  get 'rpm_chart_data', to: 'dashboard#rpm_chart_data'
end
