# frozen_string_literal: true

module DiscoursePostGeoip
  # Reads the request headers listed in the
  # discourse_post_geoip_request_headers site setting and keeps their values
  # for the duration of the request, so the post_created hook can persist them.
  #
  # The values are stored in the database only and are never serialized to the
  # client.
  module RequestHeaders
    STORE_KEY = :discourse_post_geoip_request_headers
    NAME_PATTERN = /\A[A-Za-z0-9_-]+\z/

    module_function

    # Never raises: reading headers must not be able to break posting.
    def capture(request)
      Thread.current[STORE_KEY] = read(request)
    rescue StandardError => e
      Thread.current[STORE_KEY] = nil
      report(e)
    end

    def current
      Thread.current[STORE_KEY]
    end

    def clear
      Thread.current[STORE_KEY] = nil
    end

    # Returns { "CF-Connecting-IP" => "203.0.113.5" } with the configured
    # headers that are present in the request, or nil when there is none.
    def read(request)
      return if request.nil?
      return if !SiteSetting.discourse_post_geoip_enabled

      names = header_names
      return if names.empty?

      headers = request.headers
      values = {}

      names.each do |name|
        value = normalize_value(header_value(headers, name))
        values[name] = value if value.present?
      end

      values.presence
    end

    # The setting is a list setting, stored as a pipe separated string.
    def header_names
      SiteSetting
        .discourse_post_geoip_request_headers
        .to_s
        .split("|")
        .map(&:strip)
        .select { |name| NAME_PATTERN.match?(name) }
        .uniq
    end

    # Header names are compared case-insensitively; the Rack env form
    # ("HTTP_CF_CONNECTING_IP") matches "CF-Connecting-IP".
    def header_value(headers, name)
      wanted = normalize_name(name)

      headers.each do |key, value|
        return value if normalize_name(key) == wanted
      end

      nil
    end

    def normalize_name(name)
      name.to_s.strip.sub(/\AHTTP_/i, "").upcase.tr("-", "_")
    end

    # Rack exposes a repeated header as an array on some servers. Join it the
    # same way HTTP combines repeated field lines, so the stored value is always
    # a string instead of the result of Array#to_s.
    def normalize_value(value)
      return if value.nil?

      if value.is_a?(Array)
        value.flatten.map { |part| part.to_s.strip }.reject(&:blank?).join(", ").presence
      else
        value.to_s.strip.presence
      end
    end

    def report(error)
      Discourse.warn_exception(
        error,
        message: "discourse-post-geoip could not read the configured request headers",
      )
    rescue StandardError
      nil
    end
  end
end
