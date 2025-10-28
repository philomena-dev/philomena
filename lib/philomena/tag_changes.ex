defmodule Philomena.TagChanges do
  @moduledoc """
  The TagChanges context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo
  alias PhilomenaQuery.Search
  alias Philomena.TagChangeRevertWorker
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges.Query
  alias Philomena.TagChanges.SearchIndex
  alias Philomena.IndexWorker
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  # Accepts a list of TagChanges.TagChange IDs.
  def mass_revert(ids, attributes) do
    tag_changes =
      Repo.all(
        from tc in TagChange,
          inner_join: i in assoc(tc, :image),
          where: tc.id in ^ids and i.hidden_from_users == false,
          order_by: [desc: :created_at],
          preload: [tags: [:tag, :tag_change]]
      )

    case mass_revert_tags(Enum.flat_map(tag_changes, & &1.tags), attributes) do
      {:ok, _result} ->
        {:ok, tag_changes}

      error ->
        error
    end
  end

  # Accepts a list of TagChanges.Tag objects with tag_change and tag relations preloaded.
  def mass_revert_tags(tags, attributes) do
    # Sort tags by tag change creation date, then uniq them by tag ID
    # to keep the first, aka the latest, record. Then prepare the struct
    # for the batch updater.
    changes_per_image =
      tags
      |> Enum.group_by(& &1.tag_change.image_id)
      |> Enum.map(fn {image_id, instances} ->
        changed_tags =
          instances
          |> Enum.sort_by(& &1.tag_change.created_at, :desc)
          |> Enum.uniq_by(& &1.tag_id)

        {added_tags, removed_tags} = Enum.split_with(changed_tags, & &1.added)

        # We send removed tags to be added, and added to be removed. That's how reverting works!
        %{
          image_id: image_id,
          added_tags: Enum.map(removed_tags, & &1.tag),
          removed_tags: Enum.map(added_tags, & &1.tag)
        }
      end)

    Images.batch_update(changes_per_image, attributes)
  end

  def full_revert(%{user_id: _user_id, attributes: _attributes} = params),
    do: Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [params])

  def full_revert(%{ip: _ip, attributes: _attributes} = params),
    do: Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [params])

  def full_revert(%{fingerprint: _fingerprint, attributes: _attributes} = params),
    do: Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [params])

  @doc """
  Updates tag change search indices when a user's name changes.

  ## Examples

      iex> user_name_reindex("old_username", "new_username")
      :ok

  """
  def user_name_reindex(old_name, new_name) do
    data = SearchIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(TagChange, data.query, data.set_replacements, data.replacements)
  end

  @doc """
  Queues a tag change for reindexing.

  Adds the tag change to the indexing queue to update its search index.

  ## Examples

      iex> reindex_tag_change(tag_change)
      %TagChange{}

  """
  def reindex_tag_change(%TagChange{} = tag_change) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["TagChanges", "id", [tag_change.id]])

    tag_change
  end

  @doc """
  Queues all listed tag change IDs for search index updates.
  Returns the list unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_tag_changes([1, 2, 3])
      [1, 2, 3]

  """
  def reindex_tag_changes(tag_change_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["TagChanges", "id", tag_change_ids])

    tag_change_ids
  end

  @doc """
  Queues all tag changes associated with a list of image IDs for search index updates.
  Returns the list unchanged, for use in a pipeline.

  ## Examples

      iex> reindex_tag_changes_on_images([1, 2, 3])
      [1, 2, 3]

  """
  def reindex_tag_changes_on_images(image_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["TagChanges", "image_id", image_ids])

    image_ids
  end

  @doc """
  Returns a list of associations to preload when indexing tag changes.

  ## Examples

      iex> indexing_preloads()
      [:image, :tags, :user]

  """
  def indexing_preloads do
    alias_tags_query = select(Tag, [:aliased_tag_id, :name])

    base_tags_query =
      Tag
      |> select([:id, :name])
      |> preload(aliases: ^alias_tags_query)

    image_query =
      Image
      |> select([:anonymous, :user_id])

    [
      image: image_query,
      tags: [
        tag: base_tags_query
      ],
      user: select(User, [:name])
    ]
  end

  @doc """
  Reindexes tag changes based on a column condition.

  Updates the search index for all tag changes matching the given column condition.
  Used for batch reindexing of tag changes.

  ## Examples

      iex> perform_reindex(:id, [1, 2, 3])
      {:ok, [%TagChange{}, ...]}

  """
  def perform_reindex(column, condition) do
    TagChange
    |> preload(^indexing_preloads())
    |> where([tc], field(tc, ^column) in ^condition)
    |> Search.reindex(TagChange)
  end

  defp tags_to_tag_change(_, nil, _), do: []

  defp tags_to_tag_change(tag_change, tags, added) do
    tags
    |> Enum.map(
      &%{
        tag_change_id: tag_change.id,
        tag_id: &1.id,
        added: added
      }
    )
  end

  @doc """
  Creates a tag_change.
  """
  def create_tag_change(image, attrs, added_tags, removed_tags) do
    user = attrs[:user]
    user_id = if user, do: user.id, else: nil

    {:ok, tc} =
      %TagChange{
        image_id: image.id,
        user_id: user_id,
        ip: attrs[:ip],
        fingerprint: attrs[:fingerprint]
      }
      |> Repo.insert()

    {added_count, nil} =
      Repo.insert_all(TagChanges.Tag, tags_to_tag_change(tc, added_tags, true))

    {removed_count, nil} =
      Repo.insert_all(TagChanges.Tag, tags_to_tag_change(tc, removed_tags, false))

    reindex_tag_change(tc)

    {:ok, {added_count, removed_count}}
  end

  @doc """
  Deletes a TagChange.

  ## Examples

      iex> delete_tag_change(tag_change)
      {:ok, %TagChange{}}

      iex> delete_tag_change(tag_change)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tag_change(%TagChange{} = tag_change) do
    case Repo.delete(tag_change) do
      {:ok, %TagChange{} = tc} = result ->
        Search.delete_document(tc.id, TagChange)
        result

      result ->
        result
    end
  end

  def count_tag_changes(field_name, value) do
    TagChange
    |> where([c], field(c, ^field_name) == ^value)
    |> join(:left, [c], t in assoc(c, :tags))
    |> select([c, t], {count(c, :distinct), count(t)})
    |> Repo.one()
  end

  def load(user, params, pagination) do
    {:ok, query} = Query.compile(get_query(params), user: user)

    TagChange
    |> Search.search_definition(
      %{
        query: %{
          bool: %{
            must: [query]
          }
        },
        sort: parse_sort(params)
      },
      pagination
    )
    |> Search.search_records(
      preload(TagChange, [:user, image: [:user, :sources, tags: :aliases], tags: [:tag]])
    )
  end

  defp parse_sort(%{"sf" => sf, "sd" => sd})
       when sf in ["created_at", "tag_count", "added_tag_count", "removed_tag_count"] and
              sd in ["desc", "asc"] do
    [%{sf => sd}, %{"id" => sd}]
  end

  defp parse_sort(_params) do
    [%{created_at: :desc}, %{id: :desc}]
  end

  defp get_query(%{"tcq" => ""}), do: "*"

  defp get_query(%{"tcq" => q}), do: q

  defp get_query(_), do: "*"
end
