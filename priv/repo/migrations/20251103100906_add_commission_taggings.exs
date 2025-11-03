defmodule Philomena.Repo.Migrations.AddCommissionTaggings do
  use Ecto.Migration

  def change do
    # First create commission taggings
    create table("commission_taggings", primary_key: false) do
      add :commission_id, references(:commissions, on_delete: :delete_all), primary_key: true
      add :tag_id, references(:tags, on_delete: :delete_all), primary_key: true
    end

    create unique_index(:commission_taggings, [:commission_id, :tag_id])

    # Add a column to indicate if the artist is accepting requests
    change table("commissions") do
      add :accepting_requests, :boolean, default: false, null: false
    end

    # Then convert existing categories to tags
    execute("""
    WITH cs AS (SELECT c.id, unnest(c.categories) AS category FROM commissions c),
      ct AS (SELECT cs.id, unnest(
        CASE category
          WHEN 'Anthro' THEN ARRAY['anthro']
          WHEN 'Comics' THEN ARRAY['comic']
          WHEN 'Fetish Art' THEN ARRAY['fetish']
          WHEN 'Human and EqG' THEN ARRAY['human', 'humanoid']
          WHEN 'NSFW' THEN ARRAY['explicit', 'questionable', 'suggestive']
          WHEN 'Original Characters' THEN ARRAY['oc']
          WHEN 'Original Species' THEN ARRAY['original species']
          WHEN 'Pony' THEN ARRAY['my little pony']
          WHEN 'Safe' THEN ARRAY['safe']
          WHEN 'Shipping' THEN ARRAY['shipping']
          WHEN 'Violence and Gore' THEN ARRAY['gore', 'violence']
          WHEN 'Franchise Fan Art' THEN ARRAY['fanart']
        ) AS tag_name) FROM cs,
      t AS (SELECT ct.id AS commission_id, t.id AS tag_id FROM ct INNER JOIN tags t ON t.name=ct.tag_name)
    INSERT INTO commission_taggings (commission_id, tag_id)
    SELECT DISTINCT commission_id, tag_id FROM t;
    """)

    # And set accepting_requests based on whether "Requests" category was present
    execute("""
    UPDATE commissions
    SET accepting_requests = true
    WHERE 'Requests' = ANY(categories)
    """)

    # TODO (release 2.0): cleanup categories column
  end
end
