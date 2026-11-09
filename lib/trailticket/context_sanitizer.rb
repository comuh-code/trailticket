require "uri"
require "json"

module Trailticket
  # Never trust the browser: the collector already masks sensitive data, but
  # this runs again on the server with the app's own filter_parameters.
  # Only known keys survive, lists are capped and strings are truncated.
  class ContextSanitizer
    MASK = "[FILTERED]".freeze
    PAGE_KEYS = %w[url referrer title user_agent language timezone viewport screen captured_at].freeze
    TRAIL_KEYS = %w[type at url label].freeze
    ERROR_KEYS = %w[at type message source line column stack].freeze
    URL_KEYS = %w[url referrer source].freeze
    LONG_KEYS = %w[stack].freeze

    def self.call(raw, config: Trailticket.config)
      new(raw, config).call
    end

    def initialize(raw, config)
      @raw = normalize(raw)
      @config = config
    end

    def call
      return {} unless @raw.is_a?(Hash)

      {
        "page" => page,
        "trail" => list("trail", @config.max_trail_entries) { |entry| pick(entry, TRAIL_KEYS) },
        "fields" => list("fields", @config.max_fields) { |field| field(field) },
        "errors" => list("errors", @config.max_errors) { |error| pick(error, ERROR_KEYS) }
      }.reject { |_key, value| value.blank? }
    end

    def sensitive?(name)
      return false if name.blank?

      filter.filter(name.to_s => "x").values.first == MASK
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
      pick(@raw["page"], PAGE_KEYS)
    end

    def list(key, max)
      items = @raw[key]
      return [] unless items.is_a?(Array)

      items.last(max).filter_map { |item| yield(item) if item.is_a?(Hash) }.reject(&:blank?)
    end

    def pick(hash, keys)
      return {} unless hash.is_a?(Hash)

      hash.slice(*keys).each_with_object({}) do |(key, value), out|
        next if value.nil? || value.is_a?(Hash) || value.is_a?(Array)

        value = clean_url(value) if URL_KEYS.include?(key)
        out[key] = truncate(value, LONG_KEYS.include?(key) ? @config.max_value_length * 4 : @config.max_value_length)
      end
    end

    def field(raw)
      out = pick(raw, %w[name label type])
      return nil if out.empty?

      masked = raw["masked"] == true || out["type"] == "password" ||
               sensitive?(out["name"]) || sensitive?(out["label"])
      out["filled"] = true
      out["masked"] = masked
      if masked
        out["value"] = MASK
      elsif @config.capture_field_values && !raw["value"].nil? && !raw["value"].is_a?(Hash)
        out["value"] = truncate(Array(raw["value"]).join(", "), @config.max_value_length)
      end
      out
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
      deep_stringify(raw)
    rescue JSON::ParserError
      {}
    end

    def deep_stringify(value)
      case value
      when Hash then value.to_h { |key, val| [key.to_s, deep_stringify(val)] }
      when Array then value.map { |val| deep_stringify(val) }
      else value
      end
    end
  end
end
