# frozen_string_literal: true

require "ipaddr"

module DiscoursePostGeoip
  # Turns a full IP address into a partially masked one so that the full
  # address is never exposed on the client.
  module IpMask
    DEFAULT_IPV4_VISIBLE_OCTETS = 2
    DEFAULT_IPV6_VISIBLE_GROUPS = 4

    module_function

    # Returns a masked string, or nil when +ip+ is not a valid IP address.
    def mask(ip, ipv4_visible_octets: DEFAULT_IPV4_VISIBLE_OCTETS, ipv6_visible_groups: DEFAULT_IPV6_VISIBLE_GROUPS)
      address = parse(ip)
      return if address.nil?

      if address.ipv4?
        mask_ipv4(address, ipv4_visible_octets)
      else
        mask_ipv6(address, ipv6_visible_groups)
      end
    end

    # Returns an IPAddr, normalizing IPv4-mapped IPv6 addresses
    # (e.g. ::ffff:1.2.3.4) to plain IPv4.
    def parse(ip)
      address = IPAddr.new(ip.to_s.strip)
      address = address.native if address.ipv6? && address.ipv4_mapped?
      address
    rescue IPAddr::InvalidAddressError, ArgumentError
      nil
    end

    # 1.2.3.4 with 3 visible octets => "1.2.3.*"
    def mask_ipv4(address, visible_octets)
      visible_octets = visible_octets.to_i.clamp(1, 3)
      octets = address.to_s.split(".")
      (octets.first(visible_octets) + Array.new(4 - visible_octets, "*")).join(".")
    end

    # 2001:db8:1234:5678:9abc:: with 4 visible groups => "2001:db8:1234:5678::"
    def mask_ipv6(address, visible_groups)
      visible_groups = visible_groups.to_i.clamp(1, 7)
      groups =
        address
          .to_i
          .to_s(16)
          .rjust(32, "0")
          .scan(/.{4}/)
          .first(visible_groups)
          .map { |group| group.to_i(16).to_s(16) }

      "#{groups.join(":")}::"
    end
  end
end
