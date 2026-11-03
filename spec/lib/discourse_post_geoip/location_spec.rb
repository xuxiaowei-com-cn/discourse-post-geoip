# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoursePostGeoip::Location do
  describe ".display" do
    let(:record) do
      DiscoursePostGeoip::Record.new(country: "中国", region: "浙江", city: "杭州")
    end

    after { SiteSetting.discourse_post_geoip_location_granularity = "country|region" }

    it "shows the country only" do
      SiteSetting.discourse_post_geoip_location_granularity = "country"
      expect(described_class.display(record)).to eq("中国")
    end

    it "shows the country and region" do
      SiteSetting.discourse_post_geoip_location_granularity = "country|region"
      expect(described_class.display(record)).to eq("中国 浙江")
    end

    it "shows the country, region and city" do
      SiteSetting.discourse_post_geoip_location_granularity = "country|region|city"
      expect(described_class.display(record)).to eq("中国 浙江 杭州")
    end

    it "supports selecting non-consecutive levels" do
      SiteSetting.discourse_post_geoip_location_granularity = "country|city"
      expect(described_class.display(record)).to eq("中国 杭州")
    end

    it "falls back to the levels that are known" do
      SiteSetting.discourse_post_geoip_location_granularity = "country|region|city"
      record.city = nil
      expect(described_class.display(record)).to eq("中国 浙江")
    end
  end

  describe ".private_ip?" do
    it "detects private and loopback IPv4 addresses" do
      expect(described_class.private_ip?("192.168.1.1")).to be(true)
      expect(described_class.private_ip?("10.0.0.1")).to be(true)
      expect(described_class.private_ip?("127.0.0.1")).to be(true)
    end

    it "returns false for public addresses" do
      expect(described_class.private_ip?("223.5.5.5")).to be(false)
    end
  end
end
