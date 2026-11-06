# frozen_string_literal: true

module DiscoursePostGeoip
  # Resolves the IP address to record from a configurable request header, so
  # that installs behind a CDN or a reverse proxy can use the header their edge
  # sets (for example CF-Connecting-IP or X-Real-IP) instead of the connection
  # IP.
  #
  # Only a value that parses as an IP address is accepted; anything else falls
  # back to the IP passed by PostCreator. The value is kept for the duration of
  # the request because the post_created hook runs after the controller has
  # produced it and no longer has access to the request.
  module RequestIp
    STORE_KEY = :discourse_post_geoip_ip_address

    module_function

    # Reads the configured header from +request+ and remembers it until
    # .clear is called at the end of the request.
    def capture(request)
      store(from_headers(request&.headers))
    rescue StandardError => e
      Discourse.warn_exception(
        e,
        message: "discourse-post-geoip could not read the configured request header",
      )
      store(nil)
    end

    def current
      RequestStore.store[STORE_KEY]
    end

    # The captured header value wins; otherwise the IP provided by PostCreator
    # (the connection IP) is kept.
    def resolve(fallback_ip)
      current.presence || fallback_ip
    end

    def clear
      RequestStore.store.delete(STORE_KEY)
    end

    # Returns the IP address found in the configured header, or nil when the
    # setting is blank, the header is missing, or its value is not an IP.
    def from_headers(headers)
      name = SiteSetting.discourse_post_geoip_request_header.to_s.strip
      return if name.blank? || headers.blank?

      extract_ip(header_value(headers, name))
    end

    # Header names are compared case-insensitively and "HTTP_FOO_BAR" (the Rack
    # env form) matches "Foo-Bar".
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

    # Values such as "203.0.113.5, 70.41.3.18" (X-Forwarded-For) are split and
    # the leftmost value that parses as an IP is used. A trailing port on an
    # IPv4 address ("203.0.113.5:8080") is ignored.
    def extract_ip(value)
      return if value.blank?

      Array(value).map(&:to_s).join(",").split(",").each do |part|
        candidate = part.strip.sub(/\A(\d{1,3}(?:\.\d{1,3}){3}):\d+\z/, '\1')
        address = IpMask.parse(candidate)
        return address.to_s if address
      end

      nil
    end

    def store(value)
      RequestStore.store[STORE_KEY] = value
    end
  end
end
