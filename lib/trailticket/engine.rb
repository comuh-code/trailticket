# frozen_string_literal: true

class Trailticket::Engine < Rails::Engine
  isolate_namespace Trailticket

  initializer 'trailticket.assets' do |app|
    if defined?(Sprockets) && app.config.respond_to?(:assets) && app.config.assets.precompile
      app.config.assets.precompile += %w[trailticket.js]
    end
  end

  config.after_initialize { Trailticket.config.validate! }
end
