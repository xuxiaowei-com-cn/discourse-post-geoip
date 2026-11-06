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
require_relative "lib/discourse_post_geoip/request_ip"
require_relative "lib/discourse_post_geoip/recorder"
require_relative "lib/discourse_post_geoip/payload"
require_relative "lib/discourse_post_geoip/posts_controller_extension"

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

  # The request itself is only reachable from the controller, so capture the
  # configured header there and keep it for the duration of the request.
  reloadable_patch do
    ::PostsController.prepend(DiscoursePostGeoip::PostsControllerExtension)
  end

  # PostCreator passes the request IP in its options (posts_controller,
  # PostCreator#create), so it is available here before it is discarded. The
  # value from the configured header wins when it is a valid IP address.
  on(:post_created) do |post, opts, _user|
    ip_address = DiscoursePostGeoip::RequestIp.resolve(opts[:ip_address])
    DiscoursePostGeoip::Recorder.record(post, ip_address)
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
  ) { DiscoursePostGeoip::Payload.for_record(object.discourse_post_geoip_record) }

  # Shown when the user card is opened by clicking an avatar. UserSerializer
  # inherits from UserCardSerializer, so restrict this to the card itself to
  # avoid querying for every user in user lists.
  add_to_serializer(
    :user_card,
    :geoip,
    include_condition: -> {
      instance_of?(UserCardSerializer) && SiteSetting.discourse_post_geoip_enabled &&
        (SiteSetting.discourse_post_geoip_show_ip ||
          SiteSetting.discourse_post_geoip_show_location)
    },
  ) { DiscoursePostGeoip::Payload.for_user(object) }

  # Shown on the user profile page (including /u/<username>/summary).
  add_to_serializer(
    :user,
    :geoip,
    include_condition: -> {
      instance_of?(UserSerializer) && SiteSetting.discourse_post_geoip_enabled &&
        (SiteSetting.discourse_post_geoip_show_ip ||
          SiteSetting.discourse_post_geoip_show_location)
    },
  ) { DiscoursePostGeoip::Payload.for_user(object) }
end
