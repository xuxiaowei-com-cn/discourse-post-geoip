# frozen_string_literal: true

module DiscoursePostGeoip
  # Persists the IP address that was used to create a post, together with its
  # location (looked up once, then cached in the database).
  module Recorder
    module_function

    def record(post, ip_address)
      return if post.blank? || ip_address.blank?
      return if !SiteSetting.discourse_post_geoip_enabled
      return if private_message?(post) &&
                !SiteSetting.discourse_post_geoip_show_in_private_messages

      normalized_ip = IpMask.parse(ip_address)&.to_s
      return if normalized_ip.blank?

      record = Record.find_or_initialize_by(post_id: post.id)
      record.user_id = post.user_id
      record.topic_id = post.topic_id
      record.post_number = post.post_number
      record.ip_address = normalized_ip

      location = Location.lookup(normalized_ip)
      if location.present?
        record.country = location[:country]
        record.region = location[:region]
        record.city = location[:city]
        record.geolocated_ip = normalized_ip
      end

      record.save! if record.new_record? || record.changed?
    rescue StandardError => e
      Discourse.warn_exception(
        e,
        message: "discourse-post-geoip could not record the IP address of post #{post&.id}",
      )
    end

    def private_message?(post)
      !!post.topic&.private_message?
    end
  end
end
