require "rails/generators"

module Trailticket
  module Generators
    # bin/rails g trailticket:install [--path=/trailticket]
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :path, type: :string, default: "/trailticket", desc: "Where to mount the engine"

      def create_initializer
        template "initializer.rb", "config/initializers/trailticket.rb"
      end

      def mount_engine
        route %(mount Trailticket::Engine, at: "#{options[:path]}")
      end

      def copy_migrations
        rails_command "trailticket:install:migrations"
      end

      def next_steps
        say <<~MSG, :green

          Trailticket installed. Next:
            1. bin/rails db:migrate
            2. Edit config/initializers/trailticket.rb (who opens, who manages)
            3. Screenshots need Active Storage (bin/rails active_storage:install)
            4. Load the collector, e.g. with importmap:
                 pin "trailticket", to: "trailticket.js"
               and start it with endpoint: "#{options[:path]}"
        MSG
      end
    end
  end
end
