# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoursePostGeoip::Recorder do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic, post_number: 1) }

  before do
    SiteSetting.discourse_post_geoip_enabled = true
    SiteSetting.discourse_post_geoip_show_in_private_messages = true
  end

  after do
    SiteSetting.discourse_post_geoip_enabled = false
    SiteSetting.discourse_post_geoip_show_in_private_messages = true
  end

  describe ".record" do
    it "stores the IP address and the floor of the topic itself" do
      described_class.record(post, "114.114.114.114")

      record = post.reload.discourse_post_geoip_record
      expect(record.topic_id).to eq(topic.id)
      expect(record.post_number).to eq(1)
      expect(record.ip_address.to_s).to eq("114.114.114.114")
    end

    it "stores the floor of a reply" do
      reply = Fabricate(:post, topic: topic, post_number: 2)

      described_class.record(reply, "114.114.114.114")

      expect(reply.reload.discourse_post_geoip_record.post_number).to eq(2)
    end

    it "does not record anything when the plugin is disabled" do
      SiteSetting.discourse_post_geoip_enabled = false

      described_class.record(post, "114.114.114.114")

      expect(DiscoursePostGeoip::Record.where(post_id: post.id).count).to eq(0)
    end
  end
end
