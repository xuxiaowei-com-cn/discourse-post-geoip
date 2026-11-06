# frozen_string_literal: true

module DiscoursePostGeoip
  # Captures the configured request headers before the post is created, so the
  # post_created hook can store their values on the record.
  module PostsControllerExtension
    def create
      DiscoursePostGeoip::RequestHeaders.capture(request)
      super
    ensure
      DiscoursePostGeoip::RequestHeaders.clear
    end
  end
end
