# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoursePostGeoip::RequestHeaders do
  before { SiteSetting.discourse_post_geoip_enabled = true }

  after do
    SiteSetting.discourse_post_geoip_request_headers = ""
    SiteSetting.discourse_post_geoip_enabled = false
    described_class.clear
  end

  def request_with(headers)
    Struct.new(:headers).new(headers)
  end

  describe ".read" do
    it "returns nil when no header is configured" do
      expect(described_class.read(request_with("CF-Connecting-IP" => ["203.0.113.5"]))).to be_nil
    end

    it "returns the configured headers that are present" do
      SiteSetting.discourse_post_geoip_request_headers = "CF-Connecting-IP|X-Real-IP"

      expect(
        described_class.read(
          request_with("CF-Connecting-IP" => "203.0.113.5", "X-Other" => "1"),
        ),
      ).to eq("CF-Connecting-IP" => ["203.0.113.5"])
    end

    it "matches header names case-insensitively and supports the Rack env form" do
      SiteSetting.discourse_post_geoip_request_headers = "CF-Connecting-IP"

      expect(described_class.read(request_with("HTTP_CF_CONNECTING_IP" => "203.0.113.5"))).to eq(
        "CF-Connecting-IP" => ["203.0.113.5"],
      )
    end

    it "keeps repeated header values given as an array" do
      SiteSetting.discourse_post_geoip_request_headers = "X-Forwarded-For"

      expect(
        described_class.read(
          request_with("X-Forwarded-For" => ["203.0.113.5", " 70.41.3.18 ", nil]),
        ),
      ).to eq("X-Forwarded-For" => ["203.0.113.5", "70.41.3.18"])
    end

    it "stores a single value as a one element array" do
      SiteSetting.discourse_post_geoip_request_headers = "X-Real-IP"

      expect(described_class.read(request_with("X-Real-IP" => ["203.0.113.5"]))).to eq(
        "X-Real-IP" => ["203.0.113.5"],
      )
    end

    it "ignores header names that are not valid" do
      SiteSetting.discourse_post_geoip_request_headers = "bad header|X-Real-IP"

      expect(described_class.read(request_with("X-Real-IP" => "203.0.113.5"))).to eq(
        "X-Real-IP" => ["203.0.113.5"],
      )
    end

    it "returns nil when the plugin is disabled" do
      SiteSetting.discourse_post_geoip_enabled = false
      SiteSetting.discourse_post_geoip_request_headers = "X-Real-IP"

      expect(described_class.read(request_with("X-Real-IP" => ["203.0.113.5"]))).to be_nil
    end
  end

  describe ".capture" do
    it "keeps the values until cleared" do
      SiteSetting.discourse_post_geoip_request_headers = "X-Real-IP"

      described_class.capture(request_with("X-Real-IP" => ["203.0.113.5"]))

      expect(described_class.current).to eq("X-Real-IP" => ["203.0.113.5"])

      described_class.clear

      expect(described_class.current).to be_nil
    end

    it "never raises" do
      SiteSetting.discourse_post_geoip_request_headers = "X-Real-IP"
      request = Object.new
      def request.headers
        raise "boom"
      end

      expect { described_class.capture(request) }.not_to raise_error
      expect(described_class.current).to be_nil
    end
  end
end
