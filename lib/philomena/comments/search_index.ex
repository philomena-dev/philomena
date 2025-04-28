defmodule Philomena.Comments.SearchIndex do
  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def index_name do
    "comments"
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
          created_at: %{type: "date"},
          updated_at: %{type: "date"},
          ip: %{type: "ip"},
          fingerprint: %{type: "keyword"},
          image_id: %{type: "keyword"},
          user_id: %{type: "keyword"},
          author: %{type: "keyword"},
          image_tag_ids: %{type: "keyword"},
          anonymous: %{type: "boolean"},
          hidden_from_users: %{type: "boolean"},
          body: %{type: "text", analyzer: "snowball"},
          approved: %{type: "boolean"},
          deleted_by_user: %{type: "keyword"},
          deleted_by_user_id: %{type: "keyword"},
          deletion_reason: %{type: "text", analyzer: "snowball"},
          destroyed_content: %{type: "boolean"}
        }
      }
    }
  end

  @impl true
  def as_json(comment) do
    %{
      id: comment.id,
      created_at: comment.created_at,
      updated_at: comment.updated_at,
      ip: to_string(comment.ip),
      fingerprint: comment.fingerprint,
      image_id: comment.image_id,
      user_id: comment.user_id,
      author: if(!!comment.user, do: String.downcase(comment.user.name)),
      image_tag_ids: comment.image.tags |> Enum.map(& &1.id),
      anonymous: comment.anonymous,
      hidden_from_users: comment.image.hidden_from_users || comment.hidden_from_users,
      body: comment.body,
      approved: comment.image.approved && comment.approved,
      deleted_by_user: if(!!comment.deleted_by, do: String.downcase(comment.deleted_by.name)),
      deleted_by_user_id: comment.deleted_by_id,
      deletion_reason: comment.deletion_reason,
      destroyed_content: comment.destroyed_content
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    old_name = String.downcase(old_name)
    new_name = String.downcase(new_name)

    %{
      query: %{
        bool: %{
          should: [
            %{term: %{author: old_name}},
            %{term: %{deleted_by_user: old_name}}
          ]
        }
      },
      replacements: [
        %{path: ["author"], old: old_name, new: new_name},
        %{path: ["deleted_by_user"], old: old_name, new: new_name}
      ],
      set_replacements: []
    }
  end
end
