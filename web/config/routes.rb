# frozen_string_literal: true

Trailticket::Web.routes.draw do
  root to: 'tickets#board'
  get 'list', to: 'tickets#index', as: :list
  get 'tickets/:id', to: 'tickets#show', as: :ticket
  patch 'tickets/:id/status', to: 'tickets#status', as: :ticket_status
  post 'tickets/:ticket_id/messages', to: 'messages#create', as: :ticket_messages
  get 'tickets/:id/screenshot', to: 'tickets#screenshot', as: :ticket_screenshot
  get 'assets/:file', to: 'assets#show', as: :web_asset, format: false,
                      constraints: { file: /[a-z_-]+\.(css|js)/ }
end
