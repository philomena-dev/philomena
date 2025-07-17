defmodule Philomena.Galleries.SearchIndex do
  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def index_name do
    "galleries"
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
          image_count: %{type: "integer"},
          watcher_count: %{type: "integer"},
          updated_at: %{type: "date"},
          created_at: %{type: "date"},
          title: %{type: "keyword"},
          creator_id: %{type: "keyword"},
          creator: %{type: "keyword"},
          image_ids: %{type: "keyword"},
          description: %{type: "text", analyzer: "snowball"},
          thumbnail_id: %{type: "keyword"},
          spoiler_warning: %{type: "text", analyzer: "snowball"}
        }
      }
    }
  end

  @impl true
  def as_json(gallery) do
    %{
      id: gallery.id,
      image_count: gallery.image_count,
      watcher_count: length(gallery.subscribers),
      updated_at: gallery.updated_at,
      created_at: gallery.created_at,
      title: String.downcase(gallery.title),
      creator_id: gallery.creator_id,
      creator: String.downcase(gallery.creator.name),
      image_ids: Enum.map(gallery.interactions, & &1.image_id),
      description: gallery.description,
      thumbnail_id: gallery.thumbnail_id,
      spoiler_warning: gallery.spoiler_warning
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    old_name = String.downcase(old_name)
    new_name = String.downcase(new_name)

    %{
      query: %{term: %{creator: old_name}},
      replacements: [%{path: ["creator"], old: old_name, new: new_name}],
      set_replacements: []
    }
  end
end
