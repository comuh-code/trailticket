# frozen_string_literal: true

module ScreenshotHelpers
  PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk' \
        'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='

  def png_data_url
    "data:image/png;base64,#{PNG}"
  end

  def data_url(content_type, content)
    "data:#{content_type};base64,#{Base64.strict_encode64(content)}"
  end
end

RSpec.configure do |config|
  config.include ScreenshotHelpers
end
