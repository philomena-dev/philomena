defmodule Philomena.Users.SearchIndex do
  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def index_name do
    "users"
  end

  @impl true
  def mapping do
    %{
      settings: %{
        index: %{
          number_of_shards: 5,
          max_result_window: 10_000_000
        }
      },
      mappings: %{
        dynamic: false,
        properties: %{
          id: %{type: "integer"},
          name_or_email: %{type: "keyword"},
          name: %{type: "keyword"},
          slug: %{type: "keyword"},
          role: %{type: "keyword"},
          description: %{type: "text", analyzer: "snowball"},
          email: %{type: "keyword"},
          otp_required_for_login: %{type: "boolean"},
          forum_posts_count: %{type: "integer"},
          topic_count: %{type: "integer"},
          uploads_count: %{type: "integer"},
          votes_cast_count: %{type: "integer"},
          comments_posted_count: %{type: "integer"},
          metadata_updates_count: %{type: "integer"},
          images_favourited_count: %{type: "integer"},
          created_at: %{type: "date"},
          confirmed: %{type: "boolean"},
          confirmed_at: %{type: "date"},
          locked: %{type: "boolean"},
          locked_at: %{type: "date"},
          deleted: %{type: "boolean"},
          deleted_at: %{type: "date"},
          deleted_by_user_id: %{type: "keyword"},
          deleted_by_user: %{type: "keyword"},
          scratchpad: %{type: "text", analyzer: "snowball"},
          custom_avatar: %{type: "boolean"},
          verified: %{type: "boolean"},
          personal_title: %{type: "text", analyzer: "snowball"},
          current_filter_id: %{type: "keyword"},
          forced_filter_id: %{type: "keyword"},
          banned_until: %{type: "date"},
          last_renamed_at: %{type: "date"},
          names: %{type: "keyword"}
        }
      }
    }
  end

  @impl true
  def as_json(user) do
    %{
      id: user.id,
      name_or_email: [String.downcase(user.name), String.downcase(user.email)],
      name: String.downcase(user.name),
      slug: String.downcase(user.slug),
      role: user.role,
      otp_required_for_login: user.otp_required_for_login,
      description: String.downcase(user.description || ""),
      email: String.downcase(user.email),
      forum_posts_count: user.forum_posts_count,
      topic_count: user.topic_count,
      uploads_count: user.uploads_count,
      votes_cast_count: user.votes_cast_count,
      comments_posted_count: user.comments_posted_count,
      metadata_updates_count: user.metadata_updates_count,
      images_favourited_count: user.images_favourited_count,
      created_at: user.created_at,
      confirmed: !!user.confirmed_at,
      confirmed_at: user.confirmed_at,
      locked: !!user.locked_at,
      locked_at: user.locked_at,
      deleted: !!user.deleted_at,
      deleted_at: user.deleted_at,
      deleted_by_user_id: user.deleted_by_user_id,
      deleted_by_user: if(!!user.deleted_by_user, do: String.downcase(user.deleted_by_user.name)),
      scratchpad: String.downcase(user.scratchpad || ""),
      custom_avatar: !!user.avatar,
      verified: user.verified,
      personal_title: String.downcase(user.personal_title || ""),
      current_filter_id: user.current_filter_id,
      forced_filter_id: user.forced_filter_id,
      banned_until: user.bans |> Enum.filter(& &1.enabled) |> Enum.map(& &1.valid_until),
      last_renamed_at: user.last_renamed_at,
      names: user.name_changes |> Enum.map(&String.downcase(&1.name))
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    old_name = String.downcase(old_name)
    new_name = String.downcase(new_name)

    %{
      query: %{term: %{deleted_by_user: old_name}},
      replacements: [%{path: ["deleted_by_user"], old: old_name, new: new_name}],
      set_replacements: []
    }
  end
end
