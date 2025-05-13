defmodule Philomena.TagChanges do
  @moduledoc """
  The TagChanges context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.TagChangeRevertWorker
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias Philomena.Images
  alias Philomena.Tags.Tag

  def mass_revert(ids, attributes) do
    tag_changes =
      Repo.all(
        from tc in TagChange,
          inner_join: i in assoc(tc, :image),
          where: tc.id in ^ids and i.hidden_from_users == false,
          order_by: [desc: :created_at],
          preload: [tags: [:tag, :tag_change]]
      )

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

    Images.batch_update(
      Enum.map(image_ids, fn id ->
        %{
          image_id: id,
          added_tags:
            removed
            |> Enum.filter(&(&1.tag_change.image_id == id))
            |> Enum.map(fn tct ->
              tct.tag
            end),
          removed_tags:
            added
            |> Enum.filter(&(&1.tag_change.image_id == id))
            |> Enum.map(fn tct ->
              tct.tag
            end)
        }
      end),
      attributes
    )
    |> case do
      {:ok, _result} ->
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
    Repo.aggregate(from(tc in TagChange, where: field(tc, ^field_name) == ^value), :count, :id)
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
        Repo.one(from tc in query, select: count(field(tc, ^count_field), :distinct))
      end

    query =
      query
      |> preload([:user, image: [:user, :sources, tags: :aliases], tags: [:tag]])
      |> group_by([tc], tc.id)
      |> order_by([desc: :created_at])

    {Repo.paginate(query, pagination), item_count}
  end

  defp base_query(%{ip: ip}) do
    from tc in TagChange, where: fragment("? >>= ip", ^ip)
  end

  defp base_query(%{field: field_name, value: value}) do
    from tc in TagChange, where: field(tc, ^field_name) == ^value
  end

  defp base_query(_) do
    from(tc in TagChange)
  end

  defp added_or_tag_field(query, %{added: nil, tag: nil}), do: query

  defp added_or_tag_field(query, attrs) do
    query =
      from tc in query,
        inner_join: tct in TagChanges.Tag,
        on: tc.id == tct.tag_change_id

    query
    |> added_field(attrs)
    |> tag_field(attrs)
    |> tag_id_field(attrs)
  end

  defp added_field(query, %{added: nil}), do: query

  defp added_field(query, %{added: added}),
    do: from([_tc, tct] in query, where: tct.added == ^added)

  defp added_field(query, _), do: query

  defp tag_field(query, %{tag: nil}), do: query

  defp tag_field(query, %{tag: tag}),
    do: from([_tc, tct] in query, inner_join: t in Tag, on: t.id == tct.tag_id, where: t.name == ^tag)

  defp tag_field(query, _), do: query

  defp tag_id_field(query, %{tag_id: nil}), do: query

  defp tag_id_field(query, %{tag_id: id}),
    do: from([_tc, tct] in query, where: tct.tag_id == ^id)

  defp tag_id_field(query, _), do: query
end
