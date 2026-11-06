# frozen_string_literal: true

class AddUserAgentAndRefererToDiscoursePostGeoipRecords < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_post_geoip_records, :user_agent, :text
    add_column :discourse_post_geoip_records, :referer, :text
  end
end
