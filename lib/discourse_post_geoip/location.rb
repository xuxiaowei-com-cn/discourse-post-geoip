# frozen_string_literal: true

module DiscoursePostGeoip
  # Resolves and caches the location of an IP address with the MaxMind database
  # that Discourse itself uses (vendor/data/GeoLite2-City.mmdb).
  #
  # The location is stored on the record, so it is only looked up once per IP
  # address. When the stored IP record is changed manually (or the MaxMind
  # database was not available when the post was created), the location is
  # looked up again on the next display.
  module Location
    GRANULARITIES = %w[country region city].freeze

    module_function

    # Returns { country:, region:, city: } with the names in the site's default
    # language. Missing levels are nil and unknown IPs return an empty hash.
    def lookup(ip)
      return {} if ip.blank?

      locale = SiteSetting.default_locale.presence || :en
      data = DiscourseIpInfo.get(ip.to_s, locale: locale)
      return {} if data.blank?

      {
        country: data[:country].presence,
        region: data[:region].presence,
        city: data[:city].presence,
      }.compact
    rescue StandardError => e
      Discourse.warn_exception(
        e,
        message: "discourse-post-geoip could not look up the location of #{ip}",
      )
      {}
    end

    # Builds the location string for a post record, honouring the granularity
    # setting.
    def display(record)
      return if record.blank?

      cache_location!(record)
      value = format(country: record.country, region: record.region, city: record.city)
      return value if value.present?

      private_ip_label(record.ip)
    rescue StandardError => e
      Discourse.warn_exception(
        e,
        message: "discourse-post-geoip could not display the location of post #{record&.post_id}",
      )
      nil
    end

    LEVELS = %w[country region city].freeze

    # Joins the levels selected in the multi-select granularity setting.
    # The setting is a pipe-separated list (e.g. "country|region").
    def format(country: nil, region: nil, city: nil, granularity: SiteSetting.discourse_post_geoip_location_granularity)
      selected = Array(granularity).flat_map { |value| value.to_s.split("|") }.map(&:strip)
      levels = LEVELS.select { |level| selected.include?(level) }
      available = { "country" => country, "region" => region, "city" => city }

      levels.map { |level| available[level] }.compact_blank.uniq.join(" ").presence
    end

    def private_ip?(ip)
      address = IpMask.parse(ip)
      return false if address.nil?

      address.private? || address.loopback? || address.link_local?
    rescue StandardError
      false
    end

    def private_ip_label(ip)
      return if !private_ip?(ip)

      I18n.t(
        "discourse_post_geoip.private_ip",
        locale: SiteSetting.default_locale.presence || :en,
      )
    end

    # Looks the location up and stores it when the record has not been
    # geolocated for its current IP yet.
    def cache_location!(record)
      ip = record.ip
      return if ip.blank?
      return if record.geolocated_ip.to_s == ip

      data = lookup(ip)
      return if data.blank?

      record.update_columns(
        country: data[:country],
        region: data[:region],
        city: data[:city],
        geolocated_ip: ip,
      )
    end
  end
end
