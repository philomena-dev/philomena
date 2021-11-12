defmodule Philomena.Repo.Migrations.AddLayouts do
  use Ecto.Migration

  def change do
    execute(
      """
      CREATE VIEW layouts AS
      WITH
        artist_link_count      AS (SELECT COUNT(*) FROM artist_links WHERE aasm_state IN ('unverified', 'link_verified', 'contacted')),
        channel_count          AS (SELECT COUNT(*) FROM channels WHERE is_live='t'),
        duplicate_report_count AS (SELECT COUNT(*) FROM duplicate_reports WHERE state='open'),
        dnp_entry_count        AS (SELECT COUNT(*) FROM dnp_entries WHERE aasm_state IN ('requested', 'claimed', 'acknowledged')),
        report_count           AS (SELECT COUNT(*) FROM reports WHERE open='t'),
        forums                 AS (SELECT array_agg(row_to_json(f)) AS array FROM forums f),
        site_notices           AS (SELECT array_agg(row_to_json(sn)) AS array FROM site_notices sn WHERE start_date <= now() AND finish_date > now())
      SELECT
        artist_link_count.count AS artist_link_count,
        channel_count.count AS channel_count,
        dnp_entry_count.count AS dnp_entry_count,
        duplicate_report_count.count AS duplicate_report_count,
        report_count.count AS report_count,
        forums.array AS forums,
        site_notices.array AS site_notices
      FROM
        artist_link_count,
        channel_count,
        duplicate_report_count,
        dnp_entry_count,
        report_count,
        forums,
        site_notices
      """,
      "DROP VIEW IF EXISTS layouts"
    )

    execute(
      """
      CREATE VIEW user_layouts AS
      SELECT
        u.id AS user_id,
        roles.array AS roles,
        my_filters.array AS my_filters,
        recent_filters.array AS recent_filters,
        unread_notification_count.count AS unread_notification_count,
        conversation_from_count.count + conversation_to_count.count AS conversation_count
      FROM users u
      INNER JOIN LATERAL (SELECT array_agg(row_to_json(r.*)) AS array FROM roles r JOIN users_roles ur ON r.id=ur.role_id WHERE ur.user_id=u.id) roles ON 't'
      INNER JOIN LATERAL (SELECT array_agg(row_to_json(f)) AS array FROM filters f WHERE f.user_id=u.id LIMIT 10) my_filters ON 't'
      INNER JOIN LATERAL (SELECT array_agg(row_to_json(f)) AS array FROM filters f WHERE f.id = ANY(u.recent_filter_ids) LIMIT 10) recent_filters ON 't'
      INNER JOIN LATERAL (SELECT COUNT(*) FROM unread_notifications WHERE user_id=u.id) unread_notification_count ON 't'
      INNER JOIN LATERAL (SELECT COUNT(*) FROM conversations WHERE from_read='f' AND from_hidden='f' AND from_id=u.id) conversation_from_count ON 't'
      INNER JOIN LATERAL (SELECT COUNT(*) FROM conversations WHERE to_read='f' AND to_hidden='f' AND to_id=u.id) conversation_to_count ON 't'
      """,
      "DROP VIEW IF EXISTS user_layouts"
    )
  end
end
