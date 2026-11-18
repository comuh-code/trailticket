module Trailticket
  # Controllers, helpers and views of the web interface (web/app/*/trailticket/panel).
  module Panel
  end

  # Built-in web interface, mounted apart from the JSON API so each can have its
  # own access rules:
  #
  #   mount Trailticket::Engine => "/trailticket"     # API + collector
  #   mount Trailticket::Web => "/admin/tickets"      # this interface
  #
  # Everything it needs (controllers, views, layout, CSS, JS, locales) lives in
  # web/ and is served by the engine itself; nothing comes from the host app.
  #
  # The code lives in Trailticket::Panel rather than in this class: an engine class
  # used as its own namespace does not get its route helpers isolated.
  class Web < ::Rails::Engine
    isolate_namespace Trailticket::Panel
    engine_name "trailticket_web"
    config.root = File.expand_path("../../web", __dir__)
  end
end
