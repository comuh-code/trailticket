# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'

Bundler.require(*Rails.groups)
require 'trailticket'

# Rails apps define their namespace module here, so it stays nested.
module Dummy # rubocop:disable Style/ClassAndModuleChildren
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path('..', __dir__)
    config.eager_load = false
    config.secret_key_base = 'dummy-secret-key-base-for-tests-only'
    config.active_record.maintain_test_schema = false
    config.active_record.dump_schema_after_migration = false
    # Development (bin/dummy) migrates the dummy tables, the gem and Active Storage.
    config.paths['db/migrate'] << File.expand_path('../../../db/migrate', __dir__)
    config.paths['db/migrate'] << ActiveStorage::Engine.root.join('db/migrate').to_s
    config.active_storage.service = :test
    config.active_job.queue_adapter = :test
    # Tests turn CSRF on only where they check it; the dev server keeps it on.
    config.action_controller.allow_forgery_protection = !Rails.env.test?
    config.action_dispatch.show_exceptions = :none if Rails.env.test?
    config.consider_all_requests_local = true
    config.i18n.default_locale = :'pt-BR' if Rails.env.development?
    # Like a regular Rails app: a pending migration shows an error page in development.
    config.active_record.migration_error = :page_load if Rails.env.development?
    config.active_support.deprecation = :stderr
    config.filter_parameters += [:email]
  end
end
