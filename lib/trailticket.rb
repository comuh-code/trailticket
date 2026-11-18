require "trailticket/version"
module Trailticket
  class Error < StandardError; end
  class InvalidScreenshot < Error; end
end

require "trailticket/configuration"
require "trailticket/context_sanitizer"
require "trailticket/screenshot_decoder"
require "trailticket/engine"

module Trailticket
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
  end
end
