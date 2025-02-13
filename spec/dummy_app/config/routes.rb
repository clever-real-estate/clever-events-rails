# frozen_string_literal: true

DummyApp::Application.routes.draw do
  resources :test_objects, only: [:update]
end
