# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoursePostGeoip::IpMask do
  describe ".mask" do
    it "masks the last two IPv4 octets by default" do
      expect(described_class.mask("114.114.114.114")).to eq("114.114.*.*")
    end

    it "honours the number of visible IPv4 octets" do
      expect(described_class.mask("114.114.114.114", ipv4_visible_octets: 1)).to eq("114.*.*.*")
      expect(described_class.mask("114.114.114.114", ipv4_visible_octets: 3)).to eq("114.114.114.*")
    end

    it "clamps the number of visible IPv4 octets" do
      expect(described_class.mask("114.114.114.114", ipv4_visible_octets: 0)).to eq("114.*.*.*")
      expect(described_class.mask("114.114.114.114", ipv4_visible_octets: 10)).to eq("114.114.114.*")
    end

    it "masks IPv6 addresses" do
      expect(described_class.mask("2001:db8:1234:5678:9abc:def0:1234:5678")).to eq(
        "2001:db8:1234:5678::",
      )
    end

    it "normalizes IPv4-mapped IPv6 addresses" do
      expect(described_class.mask("::ffff:114.114.114.114")).to eq("114.114.*.*")
    end

    it "returns nil for invalid input" do
      expect(described_class.mask(nil)).to be_nil
      expect(described_class.mask("not-an-ip")).to be_nil
    end
  end
end
