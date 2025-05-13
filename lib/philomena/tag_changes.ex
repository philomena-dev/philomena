defmodule Philomena.TagChanges do
  @moduledoc """
  The TagChanges context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.TagChangeRevertWorker
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias Philomena.Images.Tagging
  alias Philomena.Tags.Tag
  alias Philomena.Images
  alias Philomena.Comments
  alias Philomena.Tags

  # TODO: this is substantially similar to Images.batch_update/4.
  # Perhaps it should be extracted.
  def mass_revert(ids, attributes) do
    now = DateTime.utc_now(:second)
    tag_attributes = %{name: "", slug: "", created_at: now, updated_at: now}

    query =
      from tc in TagChange,
        inner_join: i in assoc(tc, :image),
        where: tc.id in ^ids and i.hidden_from_users == false,
        order_by: [desc: :created_at],
        preload: [tags: [:tag_change]]

    tag_changes = Repo.all(query)

    tags =
      tag_changes
      |> Enum.flat_map(& &1.tags)
      |> Enum.reject(&is_nil(&1.tag_id))
      |> Enum.uniq_by(&{&1.tag_id, &1.tag_change.image_id})

    {added, removed} = Enum.split_with(tags, & &1.added)

    image_ids =
      tags
      |> Enum.map(& &1.tag_change.image_id)
      |> Enum.uniq()

    tag_ids =
      tags
      |> Enum.map(& &1.tag_id)
      |> Enum.uniq()

    cached_tag_names =
      tags
      |> Enum.map(&{&1.tag_id, &1.tag_name_cache})
      |> Enum.uniq()
      |> Map.new()

    # load data so that we can cache tag names
    tag_names =
      Tag
      |> where([t], t.id in ^tag_ids)
      |> select([t], [t.id, t.name])
      |> Repo.all()
      |> Map.new(fn [id, name] -> {id, name} end)

    # merge newly loaded tags on top of cached tag names,
    # since they would be guaranteed to have up-to-date
    # names
    tag_names = Map.merge(cached_tag_names, tag_names)

    to_remove =
      added
      |> Enum.map(&{&1.tag_change.image_id, &1.tag_id})
      |> Enum.reduce(where(Tagging, fragment("'t' = 'f'")), fn {image_id, tag_id}, q ->
        or_where(q, image_id: ^image_id, tag_id: ^tag_id)
      end)
      |> select([t], [t.image_id, t.tag_id])

    to_add = Enum.map(removed, &%{image_id: &1.tag_change.image_id, tag_id: &1.tag_id})

    Repo.transaction(fn ->
      {_count, inserted} =
        Repo.insert_all(Tagging, to_add, on_conflict: :nothing, returning: [:image_id, :tag_id])

      {_count, deleted} = Repo.delete_all(to_remove)

      inserted = Enum.map(inserted, &[&1.image_id, &1.tag_id])

      all_changed = inserted ++ deleted

      # Create tag change batches for every image ID.
      new_tag_changes =
        all_changed
        |> Enum.uniq_by(fn [image_id, _] -> image_id end)
        |> Enum.map(fn [image_id, _] ->
          {:ok, tc} =
            %TagChange{
              image_id: image_id,
              user_id: attributes[:user_id],
              ip: attributes[:ip],
              fingerprint: attributes[:fingerprint],
              created_at: now,
              updated_at: now
            }
            |> Repo.insert()

          {image_id, tc}
        end)
        |> Map.new()

      # Create tags belonging to tag changes.
      added_changes =
        Enum.map(inserted, fn [image_id, tag_id] ->
          %{id: id} = Map.get(new_tag_changes, image_id)
          name = Map.get(tag_names, tag_id)

          # fail the entire transaction in case of missing tag data
          if is_nil(name) do
            raise "tag data for tag #{tag_id} is nil"
          end

          %{
            tag_change_id: id,
            tag_id: tag_id,
            tag_name_cache: name,
            added: true
          }
        end)

      removed_changes =
        Enum.map(deleted, fn [image_id, tag_id] ->
          %{id: id} = Map.get(new_tag_changes, image_id)
          name = Map.get(tag_names, tag_id)

          # fail the entire transaction in case of missing tag data
          if is_nil(name) do
            raise "tag data for tag #{tag_id} is nil"
          end

          %{
            tag_change_id: id,
            tag_id: tag_id,
            tag_name_cache: name,
            added: false
          }
        end)

      # Insert them all at once.
      Repo.insert_all(TagChanges.Tag, added_changes ++ removed_changes)

      # In order to merge into the existing tables here in one go, insert_all
      # is used with a query that is guaranteed to conflict on every row by
      # using the primary key.

      added_upserts =
        inserted
        |> Enum.group_by(fn [_image_id, tag_id] -> tag_id end)
        |> Enum.map(fn {tag_id, instances} ->
          Map.merge(tag_attributes, %{
            name: Map.get(tag_names, tag_id, ""),
            id: tag_id,
            images_count: length(instances)
          })
        end)

      removed_upserts =
        deleted
        |> Enum.group_by(fn [_image_id, tag_id] -> tag_id end)
        |> Enum.map(fn {tag_id, instances} ->
          Map.merge(tag_attributes, %{
            name: Map.get(tag_names, tag_id, ""),
            id: tag_id,
            images_count: -length(instances)
          })
        end)

      update_query = update(Tag, inc: [images_count: fragment("EXCLUDED.images_count")])

      upserts = added_upserts ++ removed_upserts

      Repo.insert_all(Tag, upserts, on_conflict: update_query, conflict_target: [:id])
    end)
    |> case do
      {:ok, _result} ->
        Images.reindex_images(image_ids)
        Comments.reindex_comments_on_images(image_ids)
        Tags.reindex_tags(Enum.map(tag_ids, &%{id: &1}))

        {:ok, tag_changes}

      error ->
        error
    end
  end

  def full_revert(%{user_id: _user_id, attributes: _attributes} = params),
    do: Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [params])

  def full_revert(%{ip: _ip, attributes: _attributes} = params),
    do: Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [params])

  def full_revert(%{fingerprint: _fingerprint, attributes: _attributes} = params),
    do: Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [params])

  @doc """
  Gets a single tag_change.

  Raises `Ecto.NoResultsError` if the Tag change does not exist.

  ## Examples

      iex> get_tag_change!(123)
      %TagChange{}

      iex> get_tag_change!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tag_change!(id), do: Repo.get!(TagChange, id)

  defp tags_to_tag_change(_, nil, _), do: []

  defp tags_to_tag_change(tag_change, tags, added) do
    tags
    |> Enum.map(
      &%{
        tag_change_id: tag_change.id,
        tag_id: &1.id,
        tag_name_cache: &1.name,
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

    {:ok, {added_count, removed_count}}
  end

  @doc """
  Updates a tag_change.

  ## Examples

      iex> update_tag_change(tag_change, %{field: new_value})
      {:ok, %TagChange{}}

      iex> update_tag_change(tag_change, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tag_change(%TagChange{} = tag_change, attrs) do
    tag_change
    |> TagChange.changeset(attrs)
    |> Repo.update()
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
    Repo.delete(tag_change)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag_change changes.

  ## Examples

      iex> change_tag_change(tag_change)
      %Ecto.Changeset{source: %TagChange{}}

  """
  def change_tag_change(%TagChange{} = tag_change) do
    TagChange.changeset(tag_change, %{})
  end

  def count_tag_changes(field_name, value) do
    Repo.aggregate(from(t in TagChange, where: field(t, ^field_name) == ^value), :count, :id)
  end

  def load(attrs, pagination) do
    {tag_changes, _} = load(attrs, nil, pagination)

    tag_changes
  end

  def load(attrs, count_field, pagination) do
    query =
      attrs
      |> base_query()
      |> added_or_tag_field(attrs)

    item_count =
      if count_field do
        Repo.one(from t in query, select: count(field(t, ^count_field), :distinct))
      end

    query =
      query
      |> preload([:user, image: [:user, :sources, tags: :aliases], tags: [:tag]])
      |> group_by([t], t.id)

    {Repo.paginate(query, pagination), item_count}
  end

  defp base_query(%{ip: ip}) do
    from t in TagChange, where: fragment("? >>= ip", ^ip)
  end

  defp base_query(%{field: field_name, value: value}) do
    from t in TagChange, where: field(t, ^field_name) == ^value
  end

  defp base_query(_) do
    from(t in TagChange)
  end

  defp added_or_tag_field(query, %{added: nil, tag: nil}), do: query

  defp added_or_tag_field(query, attrs) do
    query =
      from t in query,
        inner_join: tt in TagChanges.Tag,
        as: :tags,
        on: t.id == tt.tag_change_id

    query
    |> added_field(attrs)
    |> tag_field(attrs)
    |> tag_id_field(attrs)
  end

  defp added_field(query, %{added: nil}), do: query

  defp added_field(query, %{added: added}),
    do: from([_t, tags: tt] in query, where: tt.added == ^added)

  defp added_field(query, _), do: query

  defp tag_field(query, %{tag: nil}), do: query

  defp tag_field(query, %{tag: tag}),
    do: from([_t, tags: tt] in query, where: tt.tag_name_cache == ^tag)

  defp tag_field(query, _), do: query

  defp tag_id_field(query, %{tag_id: nil}), do: query

  defp tag_id_field(query, %{tag_id: id}),
    do: from([_t, tags: tt] in query, where: tt.tag_id == ^id)

  defp tag_id_field(query, _), do: query
end
