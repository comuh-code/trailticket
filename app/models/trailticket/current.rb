module Trailticket
  # Who is acting in the current request, recorded in the ticket history.
  # The web interface sets it from config.current_actor and the API from the
  # signed-in user; elsewhere use Trailticket.with_actor(user) { ... }.
  class Current < ActiveSupport::CurrentAttributes
    attribute :actor
  end
end
