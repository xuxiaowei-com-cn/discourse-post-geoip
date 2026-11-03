# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoursePostGeoip::Location do
  describe ".display" do
    let(:record) do
      DiscoursePostGeoip::Record.new(country: "中国", region: "浙江", city: "杭州")
    end

    after { SiteSetting.discourse_post_geoip_location_granularity = "city" }

    it "shows the country only" do
      SiteSetting.discourse_post_geoip_location_granularity = "country"
      expect(described_class.display(record)).to eq("中国")
    end

    it "shows the country and region" do
      SiteSetting.discourse_post_geoip_location_granularity = "region"
      expect(described_class.display(record)).to eq("中国 浙江")
    end

    it "shows the country, region and city" do
      SiteSetting.discourse_post_geoip_location_granularity = "city"
      expect(described_class.display(record)).to eq("中国 浙江 杭州")
    end

    it "falls back to the levels that are known" do
      SiteSetting.discourse_post_geoip_location_granularity = "city"
      record.city = nil
      expect(described_class.display(record)).to eq("中国 浙江")
    end
  end
end
