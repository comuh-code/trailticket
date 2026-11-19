module Trailticket
  class Configuration
    DEFAULT_STATUSES = %w[open in_progress waiting closed].freeze

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
    # ->(ticket, from, to, actor) {}; actor is who made the change (may be nil).
    # Lambdas with only (ticket, from, to) keep working.
    attr_accessor :on_status_changed

    # --- Tickets ---------------------------------------------------------------

    # Ordered statuses, also the board columns.
    attr_reader :statuses

    # Status of new tickets. Default: the first of `statuses`.
    attr_writer :initial_status

    # Statuses where a ticket is done (e.g. resolved and cancelled). Entering one
    # fills closed_at/closed_by, leaving them clears both. Only these tickets can be
    # archived. Default: the last of `statuses`.
    attr_writer :final_statuses

    # Final columns of the board only show tickets closed in the last N days
    # (older ones stay in the list and search). nil shows them all.
    attr_accessor :board_closed_days

    # --- Web interface (Trailticket::Web) --------------------------------------
    # Independent from can_open/can_manage, which only apply to the JSON API.

    # ->(request) { bool }: who may use the web interface. Default: nobody.
    attr_accessor :authorize

    # ->(request) { record or nil }: who is acting, stored as closed_by.
    attr_accessor :current_actor

    # ->(record) { String }: how authors and subjects are shown.
    attr_accessor :author_label, :subject_label

    # Partial rendered on the ticket page with a `ticket` local, for the app's own
    # context (e.g. "admin/tickets/context"). Optional.
    attr_accessor :context_partial

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

      @statuses = DEFAULT_STATUSES
      @authorize = ->(_request) { false }
      @current_actor = ->(_request) {}
      @author_label = ->(record) { "#{record.class.name} ##{record.id}" }
      @subject_label = ->(record) { "#{record.class.name} ##{record.id}" }
      @context_partial = nil
      @board_closed_days = 7

      @sensitive_fields = %w[pass secret token card cvv cvc cpf cnpj ssn iban] + [/\Aotp\z/i, /\Apin\z/i]
      @capture_field_values = true
      @max_trail_entries = 50
      @max_fields = 100
      @max_errors = 20
      @max_value_length = 500

      @max_screenshot_bytes = 5 * 1024 * 1024
      @screenshot_content_types = %w[image/png image/jpeg image/webp]
    end

    def statuses=(list)
      list = Array(list).map(&:to_s).uniq
      raise ArgumentError, "statuses needs at least two entries (initial and final)" unless list[1]

      @statuses = list.freeze
    end

    def initial_status
      (@initial_status || statuses.first).to_s
    end

    def final_statuses
      Array(@final_statuses || statuses.last).map(&:to_s)
    end

    # Run after the app boots, so a typo fails early instead of on the first ticket.
    def validate!
      unknown = ([initial_status] + final_statuses) - statuses
      if unknown.any?
        raise ArgumentError,
              "Trailticket: unknown status #{unknown.join(', ')} (statuses: #{statuses.join(', ')})"
      end
      if final_statuses.include?(initial_status)
        raise ArgumentError, "Trailticket: initial_status cannot be final"
      end
      raise ArgumentError, "Trailticket: final_statuses cannot be empty" if final_statuses.empty?

      self
    end

    def user_klass
      user_class.to_s.constantize
    end
  end
end
