require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"

Bundler.require(*Rails.groups)
require "trailticket"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.secret_key_base = "dummy-secret-key-base-for-tests-only"
    config.active_record.maintain_test_schema = false
    config.active_storage.service = :test
    config.active_job.queue_adapter = :test
    config.action_controller.allow_forgery_protection = false
    config.action_dispatch.show_exceptions = :none
    config.active_support.deprecation = :stderr
    config.filter_parameters += [:email]
  end
end
