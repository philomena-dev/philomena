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
  alias Philomena.Images.Image
  alias Philomena.Tags.Tag

  # Accepts a list of TagChanges.TagChange IDs.
  def mass_revert(ids, attributes) do
    Repo.all(
      from tc in TagChange,
        inner_join: i in assoc(tc, :image),
        where: tc.id in ^ids and i.hidden_from_users == false,
        order_by: [desc: :created_at],
        preload: [:tags]
    )
    |> mass_revert_tags(attributes)
  end

  # Accepts a list of `TagChange` structs with the `tags` pre-filled. If you
  # don't want to revert all tags from a tag change, then filter out some tags
  # from the tag changes `tags` fields.
  @spec mass_revert_tags([TagChange.t()], map()) ::
          {:ok, [TagChange.t()], integer()} | {:error, any()}
  def mass_revert_tags(tag_changes, attributes) do
    # Calculate the revert operations for each image.
    reverts_per_image =
      tag_changes
      |> Enum.group_by(& &1.image_id)
      |> Enum.map(fn {image_id, tag_changes} ->
        # The tag changes are already sorted by created_at in descending order
        # so if we run a `uniq_by` for their tags, we'll leave only the most
        # recent change per each tag.
        {added_tags, removed_tags} =
          tag_changes
          |> Enum.flat_map(& &1.tags)
          |> Enum.uniq_by(& &1.tag_id)
          |> Enum.split_with(& &1.added)

        # We send removed tags to be added, and added to be removed. That's how reverting works!
        %{
          image_id: image_id,
          added_tag_ids: Enum.map(removed_tags, & &1.tag_id),
          removed_tag_ids: Enum.map(added_tags, & &1.tag_id)
        }
      end)

    with {:ok, {total_tags_affected, _}} <- Images.batch_update(reverts_per_image, attributes) do
      {:ok, tag_changes, total_tags_affected}
    end
  end

  def full_revert(%{user_id: _user_id, attributes: _attributes} = params),
    do: Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [params])

  def full_revert(%{ip: _ip, attributes: _attributes} = params),
    do: Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [params])

  def full_revert(%{fingerprint: _fingerprint, attributes: _attributes} = params),
    do: Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [params])

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
      |> filter_anon(attrs)

    item_count =
      if count_field do
        Repo.one(from tc in query, select: count(field(tc, ^count_field), :distinct))
      end

    query =
      query
      |> preload([:user, image: [:user, :sources, tags: :aliases], tags: [:tag]])
      |> group_by([tc], tc.id)
      |> order_by(desc: :created_at)

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

  defp filter_anon(query, %{field: :user_id, value: id, filter_anon: true}) do
    from t in query,
      inner_join: i in Image,
      on: i.id == t.image_id,
      where: t.user_id == ^id and not (i.user_id == ^id and i.anonymous == true)
  end

  defp filter_anon(query, _), do: query

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
    do:
      from([_tc, tct] in query,
        inner_join: t in Tag,
        on: t.id == tct.tag_id,
        where: t.name == ^tag
      )

  defp tag_field(query, _), do: query

  defp tag_id_field(query, %{tag_id: nil}), do: query

  defp tag_id_field(query, %{tag_id: id}),
    do: from([_tc, tct] in query, where: tct.tag_id == ^id)

  defp tag_id_field(query, _), do: query
end
