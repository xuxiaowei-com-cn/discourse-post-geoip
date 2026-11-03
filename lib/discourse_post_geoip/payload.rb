# frozen_string_literal: true

module DiscoursePostGeoip
  # Builds the geoip payload used by the post and user card serializers.
  # The payload never contains the full IP address.
  module Payload
    module_function

    def for_record(record)
      return if record.blank?

      payload = {}

      if SiteSetting.discourse_post_geoip_show_ip
        payload[:ip] = IpMask.mask(
          record.ip,
          ipv4_visible_octets: SiteSetting.discourse_post_geoip_ipv4_visible_octets,
          ipv6_visible_groups: SiteSetting.discourse_post_geoip_ipv6_visible_groups,
        )
      end

      payload[:location] = Location.display(record) if SiteSetting.discourse_post_geoip_show_location

      payload.compact_blank.presence
    end

    # Geo information for a user card, based on the IP address stored on the
    # user row (users.ip_address), not on any of the user's posts.
    def for_user(user)
      return if user.blank?

      ip = user.ip_address&.to_s
      return if ip.blank?

      payload = {}

      if SiteSetting.discourse_post_geoip_show_ip
        payload[:ip] = IpMask.mask(
          ip,
          ipv4_visible_octets: SiteSetting.discourse_post_geoip_ipv4_visible_octets,
          ipv6_visible_groups: SiteSetting.discourse_post_geoip_ipv6_visible_groups,
        )
      end

      if SiteSetting.discourse_post_geoip_show_location
        data = Location.lookup(ip)
        payload[:location] = Location.format(**data) if data.present?
      end

      payload.compact_blank.presence
    end
  end
end
