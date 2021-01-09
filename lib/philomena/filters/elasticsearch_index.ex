defmodule Philomena.Filters.ElasticsearchIndex do
  @behaviour Philomena.ElasticsearchIndex

  @impl true
  def index_name do
    "filters"
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
          user_id: %{type: "keyword"},
          creator: %{type: "keyword"},
          # boolean
          public: %{type: "keyword"},
          # boolean
          system: %{type: "keyword"},
          name: %{type: "text", analyzer: "snowball"},
          description: %{type: "text", analyzer: "snowball"},
          spoilered_count: %{type: "integer"},
          hidden_count: %{type: "integer"}
        }
      }
    }
  end

  @impl true
  def as_json(filter) do
    %{
      id: filter.id,
      created_at: filter.created_at,
      user_id: filter.user_id,
      creator: if(!!filter.user, do: filter.user.name),
      public: filter.public,
      system: filter.system,
      name: filter.name,
      description: filter.description,
      spoilered_count: length(filter.spoilered_tag_ids),
      hidden_count: length(filter.hidden_tag_ids)
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    %{
      query: %{term: %{creator: old_name}},
      replacements: [%{path: ["creator"], old: old_name, new: new_name}],
      set_replacements: []
    }
  end
end