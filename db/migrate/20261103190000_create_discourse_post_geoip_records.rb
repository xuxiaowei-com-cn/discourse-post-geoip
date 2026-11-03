# frozen_string_literal: true

class CreateDiscoursePostGeoipRecords < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_post_geoip_records do |t|
      t.integer :topic_id, null: false
      t.integer :post_id, null: false
      t.integer :user_id
      t.inet :ip_address, null: false
      t.string :country
      t.string :region
      t.string :city
      t.inet :geolocated_ip
      t.timestamps
    end

    add_index :discourse_post_geoip_records, :post_id, unique: true
    add_index :discourse_post_geoip_records, :topic_id
    add_index :discourse_post_geoip_records, :user_id
  end
end
