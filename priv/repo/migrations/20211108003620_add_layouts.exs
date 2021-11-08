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
      "DROP VIEW layouts"
    )
  end
end
