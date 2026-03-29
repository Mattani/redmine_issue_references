# frozen_string_literal: true

# Routes for redmine_issue_references plugin
# See: http://guides.rubyonrails.org/routing.html

resources :projects do
  resource :issue_reference_setting, only: [:update], path: 'issue_reference_settings'
end

resources :issue_references, only: [] do
  member do
    post :dismiss
    post :restore
  end
end
