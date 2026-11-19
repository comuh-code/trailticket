# frozen_string_literal: true

require 'trailticket/version'

module Trailticket
  class Error < StandardError; end
  class InvalidScreenshot < Error; end

  module Generators; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def reset_config!
      @config = Configuration.new
    end

    def open_ticket(**attributes)
      Trailticket::OpenTicket.call(**attributes)
    end

    def with_actor(actor, &)
      Current.set(actor: actor, &)
    end
  end
end

require 'trailticket/configuration'
require 'trailticket/context_sanitizer'
require 'trailticket/screenshot_decoder'
require 'trailticket/engine'
require 'trailticket/web'
