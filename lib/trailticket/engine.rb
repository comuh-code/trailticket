module Trailticket
  class Engine < ::Rails::Engine
    isolate_namespace Trailticket

    # Sprockets apps need the collector in the precompile list. Propshaft
    # already serves app/assets/javascripts from engines.
    initializer "trailticket.assets" do |app|
      if defined?(Sprockets) && app.config.respond_to?(:assets) && app.config.assets.precompile
        app.config.assets.precompile += %w[trailticket.js]
      end
    end
  end
end
