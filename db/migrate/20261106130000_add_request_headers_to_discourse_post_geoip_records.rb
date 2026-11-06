# frozen_string_literal: true

class AddRequestHeadersToDiscoursePostGeoipRecords < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_post_geoip_records, :request_headers, :jsonb
  end
end
