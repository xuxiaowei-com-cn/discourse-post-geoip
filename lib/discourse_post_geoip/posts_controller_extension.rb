# frozen_string_literal: true

module DiscoursePostGeoip
  # Captures the IP address from the configured request header before the post
  # is created, so the post_created hook can prefer it over the connection IP.
  module PostsControllerExtension
    def create
      DiscoursePostGeoip::RequestIp.capture(request)
      super
    ensure
      DiscoursePostGeoip::RequestIp.clear
    end
  end
end
