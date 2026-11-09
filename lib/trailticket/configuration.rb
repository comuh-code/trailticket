module Trailticket
  class Configuration
    # --- Who is the user ---------------------------------------------------

    # Class of the user who opens and handles tickets ("User", "Admin"...).
    attr_accessor :user_class

    # Controller method that returns the signed-in user.
    attr_accessor :current_user_method

    # Optional block run in the controller before every action,
    # e.g. -> { authenticate_user! }.
    attr_accessor :authenticate

    # ->(user) { bool }: may open tickets and see their own.
    attr_accessor :can_open

    # ->(user) { bool }: may see all tickets, reply, add internal notes,
    # change status/priority/assignee, close and reopen.
    attr_accessor :can_manage

    # -> { relation }: who can be assigned. Without it, only "myself".
    attr_accessor :assignees

    # ->(user) { hash }: how a user is exposed in the JSON API.
    # Keep it minimal: authors and assignees see each other through it.
    attr_accessor :user_json

    # Controller the engine inherits from. Use "ActionController::API"
    # for API-only apps.
    attr_accessor :parent_controller

    # Optional block run in the controller when access is denied. Default: 403 JSON.
    attr_accessor :access_denied

    # --- Hooks (run after commit) -------------------------------------------
    attr_accessor :on_ticket_created   # ->(ticket) {}
    attr_accessor :on_message_created  # ->(message) {}
    attr_accessor :on_status_changed   # ->(ticket, from, to) {}

    # --- Context capture -----------------------------------------------------

    # Extra field/param names to mask, on top of Rails' filter_parameters.
    # Strings match as substrings, like filter_parameters.
    attr_accessor :sensitive_fields

    # Store the values of filled-in fields (sensitive ones are always masked).
    # When false, only which fields were filled is kept.
    attr_accessor :capture_field_values

    attr_accessor :max_trail_entries, :max_fields, :max_errors, :max_value_length

    # Screenshot limits.
    attr_accessor :max_screenshot_bytes, :screenshot_content_types

    def initialize
      @user_class = "User"
      @current_user_method = :current_user
      @authenticate = nil
      @can_open = ->(_user) { false }
      @can_manage = ->(_user) { false }
      @assignees = nil
      @user_json = lambda do |user|
        { id: user.id, name: user.try(:name).presence || "User ##{user.id}" }
      end
      @parent_controller = "ApplicationController"
      @access_denied = nil

      @sensitive_fields = %w[pass secret token card cvv cvc cpf cnpj ssn iban] + [/\Aotp\z/i, /\Apin\z/i]
      @capture_field_values = true
      @max_trail_entries = 50
      @max_fields = 100
      @max_errors = 20
      @max_value_length = 500

      @max_screenshot_bytes = 5 * 1024 * 1024
      @screenshot_content_types = %w[image/png image/jpeg image/webp]
    end

    def user_klass
      user_class.to_s.constantize
    end
  end
end
