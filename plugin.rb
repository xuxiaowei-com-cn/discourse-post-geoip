# frozen_string_literal: true

# name: discourse-post-geoip
# about: Records the IP address used when a post is created and displays a masked IP address and its location under the post author's username.
# version: 0.1.0
# authors: 徐晓伟
# url: https://cnb.cool/xuxiaowei.com.cn/discourse-post-geoip
# required_version: 3.2.0

enabled_site_setting :discourse_post_geoip_enabled

module ::DiscoursePostGeoip
  PLUGIN_NAME = "discourse-post-geoip"
end

require_relative "lib/discourse_post_geoip/ip_mask"
require_relative "lib/discourse_post_geoip/location"
require_relative "lib/discourse_post_geoip/recorder"

register_asset "stylesheets/common/post-geoip.scss"

after_initialize do
  require_relative "app/models/discourse_post_geoip/record"

  # Used by the post serializer and preloaded by TopicView (see below).
  reloadable_patch do
    Post.has_one :discourse_post_geoip_record,
                 class_name: "DiscoursePostGeoip::Record",
                 foreign_key: :post_id
  end

  # Preload the records for every post of a topic to avoid N+1 queries.
  TopicView.on_preload do |topic_view|
    next if !SiteSetting.discourse_post_geoip_enabled
    next if !SiteSetting.discourse_post_geoip_show_ip &&
              !SiteSetting.discourse_post_geoip_show_location

    posts = topic_view.posts
    next if posts.blank?

    ActiveRecord::Associations::Preloader.new(
      records: posts,
      associations: [:discourse_post_geoip_record],
    ).call
  end

  # PostCreator passes the request IP in its options (posts_controller,
  # PostCreator#create), so it is available here before it is discarded.
  on(:post_created) do |post, opts, _user|
    DiscoursePostGeoip::Recorder.record(post, opts[:ip_address])
  end

  on(:post_destroyed) do |post, _opts, _user|
    next if !SiteSetting.discourse_post_geoip_delete_on_post_destroy

    DiscoursePostGeoip::Record.where(post_id: post.id).delete_all
  end

  add_to_serializer(
    :post,
    :geoip,
    include_condition: -> {
      SiteSetting.discourse_post_geoip_enabled &&
        (SiteSetting.discourse_post_geoip_show_ip ||
          SiteSetting.discourse_post_geoip_show_location)
    },
  ) do
    record = object.discourse_post_geoip_record
    next if record.blank?

    ip = record.ip_address.to_s
    payload = {}

    if SiteSetting.discourse_post_geoip_show_ip
      payload[:ip] = DiscoursePostGeoip::IpMask.mask(
        ip,
        ipv4_visible_octets: SiteSetting.discourse_post_geoip_ipv4_visible_octets,
        ipv6_visible_groups: SiteSetting.discourse_post_geoip_ipv6_visible_groups,
      )
    end

    if SiteSetting.discourse_post_geoip_show_location
      payload[:location] = DiscoursePostGeoip::Location.display(record)
    end

    payload.compact_blank.presence
  end
end
