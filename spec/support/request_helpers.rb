# frozen_string_literal: true

module RequestHelpers
  # No dummy app a "sessão" vem de um header.
  def auth(user)
    { 'X-Admin-Id' => user.id.to_s }
  end

  def json
    response.parsed_body
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
