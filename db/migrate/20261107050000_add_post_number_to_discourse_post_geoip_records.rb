# frozen_string_literal: true

class AddPostNumberToDiscoursePostGeoipRecords < ActiveRecord::Migration[7.0]
  def up
    add_column :discourse_post_geoip_records, :post_number, :integer

    # Backfill the floor number for the records created before this column
    # existed. Soft-deleted posts keep their row (and their post_number), so
    # they are backfilled as well. Records whose post was hard-deleted stay
    # NULL.
    execute(<<~SQL)
      UPDATE discourse_post_geoip_records AS records
      SET post_number = posts.post_number
      FROM posts
      WHERE posts.id = records.post_id
        AND records.post_number IS NULL
    SQL
  end

  def down
    remove_column :discourse_post_geoip_records, :post_number
  end
end
