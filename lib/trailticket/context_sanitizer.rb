# frozen_string_literal: true

require 'uri'
require 'json'

# Never trust the browser: the collector already masks sensitive data, but
# this runs again on the server with the app's own filter_parameters.
# Only known keys survive, lists are capped and strings are truncated.
class Trailticket::ContextSanitizer
  MASK = '[FILTERED]'
  PAGE_KEYS = %w[url referrer title user_agent language timezone viewport screen
                 captured_at].freeze
  TRAIL_KEYS = %w[type at url label].freeze
  ERROR_KEYS = %w[at type message source line column stack].freeze
  URL_KEYS = %w[url referrer source].freeze
  LONG_KEYS = %w[stack].freeze

  def self.call(raw, config: Trailticket.config)
    new(raw, config).call
  end

  #   Trailticket::ContextSanitizer.clean_url("https://a.test/?token=abc")
  #   # => "https://a.test/?token=%5BFILTERED%5D"
  def self.clean_url(url, config: Trailticket.config)
    new({}, config).clean_url(url)
  end

  def initialize(raw, config)
    @raw = normalize(raw)
    @config = config
  end

  def call
    return {} unless @raw.is_a?(Hash)

    {
      'page' => page,
      'trail' => list('trail', @config.max_trail_entries) { |entry| pick(entry, TRAIL_KEYS) },
      'fields' => list('fields', @config.max_fields) { |field| field(field) },
      'errors' => list('errors', @config.max_errors) { |error| pick(error, ERROR_KEYS) }
    }.compact_blank
  end

  def sensitive?(name)
    return false if name.blank?

    filter.filter(name.to_s => 'x').values.first == MASK
  end

  def clean_url(value)
    url = value.to_s
    uri = URI.parse(url)
    return url if uri.query.blank?

    params = URI.decode_www_form(uri.query).map { |key, val| [key, sensitive?(key) ? MASK : val] }
    uri.query = URI.encode_www_form(params)
    uri.to_s
  rescue URI::Error, ArgumentError
    url.sub(/\?.*\z/m, "?#{MASK}")
  end

  private

  def page
    pick(@raw['page'], PAGE_KEYS)
  end

  def list(key, max)
    items = @raw[key]
    return [] unless items.is_a?(Array)

    items.last(max).filter_map { |item| yield(item) if item.is_a?(Hash) }.compact_blank
  end

  def pick(hash, keys)
    return {} unless hash.is_a?(Hash)

    hash.slice(*keys).each_with_object({}) do |(key, value), out|
      next unless scalar?(value)

      value = clean_url(value) if URL_KEYS.include?(key)
      out[key] = truncate(value, max_length(key))
    end
  end

  def scalar?(value)
    !value.nil? && !value.is_a?(Hash) && !value.is_a?(Array)
  end

  def max_length(key)
    LONG_KEYS.include?(key) ? @config.max_value_length * 4 : @config.max_value_length
  end

  def field(raw)
    out = pick(raw, %w[name label type])
    return nil if out.empty?

    out['filled'] = true
    out['masked'] = masked_field?(raw, out)
    value = field_value(raw, out['masked'])
    out['value'] = value unless value.nil?
    out
  end

  def masked_field?(raw, out)
    raw['masked'] == true || out['type'] == 'password' ||
      sensitive?(out['name']) || sensitive?(out['label'])
  end

  # MASK when masked; the (truncated) value only if the app keeps field values.
  def field_value(raw, masked)
    return MASK if masked
    return unless @config.capture_field_values && !raw['value'].nil? && !raw['value'].is_a?(Hash)

    truncate(Array(raw['value']).join(', '), @config.max_value_length)
  end

  def truncate(value, max)
    string = value.to_s
    string.length > max ? "#{string[0, max]}…" : string
  end

  def filter
    @filter ||= begin
      rails = defined?(Rails) && Rails.application ? Rails.application.config.filter_parameters : []
      ActiveSupport::ParameterFilter.new(rails + Array(@config.sensitive_fields), mask: MASK)
    end
  end

  def normalize(raw)
    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    raw = JSON.parse(raw) if raw.is_a?(String) && raw.present?
    raw.is_a?(Hash) ? raw.to_h.deep_stringify_keys : raw
  rescue JSON::ParserError
    {}
  end
end
