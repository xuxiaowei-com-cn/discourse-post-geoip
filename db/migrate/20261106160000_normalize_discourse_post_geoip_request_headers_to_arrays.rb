# frozen_string_literal: true

class NormalizeDiscoursePostGeoipRequestHeadersToArrays < ActiveRecord::Migration[7.0]
  # Header values are stored as arrays. Rows written by the previous version
  # kept a plain string, so wrap every string value into a one element array.
  def up
    execute(<<~SQL)
      UPDATE discourse_post_geoip_records AS records
      SET request_headers = normalized.headers
      FROM (
        SELECT records.id,
               jsonb_object_agg(
                 entries.key,
                 CASE
                 WHEN jsonb_typeof(entries.value) = 'string'
                 THEN jsonb_build_array(entries.value)
                 ELSE entries.value
                 END
               ) AS headers
        FROM (
          SELECT id, request_headers
          FROM discourse_post_geoip_records
          WHERE request_headers IS NOT NULL
            AND jsonb_typeof(request_headers) = 'object'
        ) AS records
        CROSS JOIN LATERAL jsonb_each(records.request_headers) AS entries(key, value)
        GROUP BY records.id
        HAVING bool_or(jsonb_typeof(entries.value) = 'string')
      ) AS normalized
      WHERE records.id = normalized.id
    SQL
  end

  def down
    # Not reversible: once a value is an array the original string form is not
    # needed, and flattening arrays would lose repeated values.
  end
end
