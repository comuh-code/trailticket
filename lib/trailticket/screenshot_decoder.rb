# frozen_string_literal: true

require 'base64'
require 'stringio'

class Trailticket::ScreenshotDecoder
  DATA_URL = %r{\Adata:(image/[a-z+.-]+);base64,(.+)\z}m
  EXTENSIONS = { 'image/png' => 'png', 'image/jpeg' => 'jpg', 'image/webp' => 'webp' }.freeze

  def self.call(input, config: Trailticket.config)
    new(config).call(input)
  end

  def initialize(config)
    @config = config
  end

  def call(input)
    return nil if input.blank?

    content_type, bytes =
      if input.is_a?(String) then from_data_url(input)
      elsif input.respond_to?(:read) then [input.try(:content_type).to_s, read(input)]
      else invalid!('is not an image')
      end

    validate!(content_type, bytes)
    { io: StringIO.new(bytes), filename: filename(content_type), content_type: content_type }
  end

  private

  def filename(content_type)
    "screenshot-#{Time.now.utc.strftime('%Y%m%d%H%M%S')}.#{EXTENSIONS.fetch(content_type)}"
  end

  def invalid!(message)
    raise Trailticket::InvalidScreenshot, message
  end

  def from_data_url(string)
    match = DATA_URL.match(string.strip)
    invalid!('is not a valid data URL') unless match
    invalid!('is too large') if match[2].bytesize > (@config.max_screenshot_bytes * 4 / 3) + 4

    [match[1], Base64.strict_decode64(match[2].delete("\n\r "))]
  rescue ArgumentError
    invalid!('is not valid base64')
  end

  def read(io)
    io.rewind if io.respond_to?(:rewind)
    bytes = io.read(@config.max_screenshot_bytes + 1).to_s.b
    invalid!('is too large') if bytes.bytesize > @config.max_screenshot_bytes
    bytes
  end

  def validate!(content_type, bytes)
    invalid!('type is not allowed') unless @config.screenshot_content_types.include?(content_type)
    invalid!('is too large') if bytes.bytesize > @config.max_screenshot_bytes
    invalid!('content does not match its type') unless magic?(content_type, bytes)
  end

  def magic?(content_type, bytes)
    case content_type
    when 'image/png' then bytes.start_with?("\x89PNG\r\n\x1A\n".b)
    when 'image/jpeg' then bytes.start_with?("\xFF\xD8\xFF".b)
    when 'image/webp' then bytes[0, 4] == 'RIFF' && bytes[8, 4] == 'WEBP'
    else false
    end
  end
end
