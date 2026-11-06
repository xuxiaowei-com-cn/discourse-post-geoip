# frozen_string_literal: true

module DiscoursePostGeoip
  # The IP address that was used when a post was created.
  #
  # Discourse does not persist the IP address of a post itself, so this plugin
  # stores it in its own table.
  #
  # +post_number+ is the 1-based floor of the post inside its topic, so the
  # record of the topic itself has +post_number+ 1.
  class Record < ActiveRecord::Base
    self.table_name = "discourse_post_geoip_records"

    belongs_to :post, class_name: "Post"
    belongs_to :user, class_name: "User", optional: true

    validates :topic_id, presence: true
    validates :post_id, presence: true, uniqueness: true
    validates :ip_address, presence: true
    # Optional because records created before the column existed, or whose post
    # was hard-deleted, have no floor number.
    validates :post_number,
              numericality: {
                only_integer: true,
                greater_than: 0,
              },
              allow_nil: true

    def ip
      ip_address&.to_s
    end
  end
end
