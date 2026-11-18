Rails.application.routes.draw do
  mount Trailticket::Engine, at: "/trailticket"
  mount Trailticket::Web, at: "/chamados"

  root to: redirect("/chamados")
end
