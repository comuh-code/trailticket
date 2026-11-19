# frozen_string_literal: true

require 'trailticket/version'

# Support tickets that carry the user's context. See README.md.
module Trailticket
  class Error < StandardError; end
  class InvalidScreenshot < Error; end

  # Namespace of the Rails generators (bin/rails g trailticket:install).
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

    # Ruby API for apps that open tickets from their own code.
    #
    #   Trailticket.open_ticket(author: current_user, title: "...", body: "...",
    #                           context: params[:context], screenshot: params[:screenshot],
    #                           page_url: request.referer, metadata: { "myapp" => { ... } })
    #
    # metadata is trusted server data, merged into the context without sanitizing;
    # it cannot use the keys page, trail, fields or errors (ArgumentError).
    # Returns the ticket; check #persisted? and #errors.
    def open_ticket(**attributes)
      Trailticket::OpenTicket.call(**attributes)
    end

    # Records who made the changes inside the block in the ticket history.
    # The web interface and the API already do this for each request.
    #
    #   Trailticket.with_actor(current_user) { ticket.update!(priority: "high") }
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
