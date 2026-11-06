# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoursePostGeoip::RequestIp do
  after do
    SiteSetting.discourse_post_geoip_request_header = ""
    described_class.clear
  end

  describe ".from_headers" do
    it "returns nil when no header is configured" do
      expect(described_class.from_headers("CF-Connecting-IP" => "114.114.114.114")).to be_nil
    end

    it "reads the configured header case-insensitively" do
      SiteSetting.discourse_post_geoip_request_header = "CF-Connecting-IP"

      expect(described_class.from_headers("cf-connecting-ip" => "114.114.114.114")).to eq(
        "114.114.114.114",
      )
    end

    it "reads the Rack env form of the header" do
      SiteSetting.discourse_post_geoip_request_header = "CF-Connecting-IP"

      expect(
        described_class.from_headers("HTTP_CF_CONNECTING_IP" => "114.114.114.114"),
      ).to eq("114.114.114.114")
    end

    it "uses the leftmost valid IP of a comma separated value" do
      SiteSetting.discourse_post_geoip_request_header = "X-Forwarded-For"

      expect(
        described_class.from_headers(
          "X-Forwarded-For" => "unknown, 114.114.114.114, 10.0.0.1",
        ),
      ).to eq("114.114.114.114")
    end

    it "ignores a trailing port" do
      SiteSetting.discourse_post_geoip_request_header = "X-Real-IP"

      expect(described_class.from_headers("X-Real-IP" => "114.114.114.114:8080")).to eq(
        "114.114.114.114",
      )
    end

    it "normalizes IPv4-mapped IPv6 addresses" do
      SiteSetting.discourse_post_geoip_request_header = "CF-Connecting-IP"

      expect(described_class.from_headers("CF-Connecting-IP" => "::ffff:114.114.114.114")).to eq(
        "114.114.114.114",
      )
    end

    it "returns nil when the value is not an IP address" do
      SiteSetting.discourse_post_geoip_request_header = "CF-Connecting-IP"

      expect(described_class.from_headers("CF-Connecting-IP" => "not-an-ip")).to be_nil
    end
  end

  describe ".capture" do
    it "keeps the header IP until cleared" do
      SiteSetting.discourse_post_geoip_request_header = "CF-Connecting-IP"
      request = Struct.new(:headers).new({ "CF-Connecting-IP" => "114.114.114.114" })

      described_class.capture(request)

      expect(described_class.current).to eq("114.114.114.114")

      described_class.clear

      expect(described_class.current).to be_nil
    end

    it "stays nil when the header is missing" do
      SiteSetting.discourse_post_geoip_request_header = "CF-Connecting-IP"
      request = Struct.new(:headers).new({})

      described_class.capture(request)

      expect(described_class.current).to be_nil
    end
  end

  describe ".resolve" do
    it "prefers the captured header IP" do
      SiteSetting.discourse_post_geoip_request_header = "CF-Connecting-IP"
      request = Struct.new(:headers).new({ "CF-Connecting-IP" => "223.5.5.5" })

      described_class.capture(request)

      expect(described_class.resolve("114.114.114.114")).to eq("223.5.5.5")
    end

    it "falls back to the connection IP" do
      expect(described_class.resolve("114.114.114.114")).to eq("114.114.114.114")
    end
  end
end
