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
  alias Philomena.Users

  require Logger

  @typedoc """
  In the successful case returns the `TagChange`s that were loaded and affected
  plus a non-negative integer with the number of tags affected by the revert.
  """
  @type mass_revert_result ::
          {:ok, [TagChange.t()], non_neg_integer()}
          | {:error, any()}

  @type tag_change_id :: integer()
  @type tag_id :: integer()

  @typedoc """
  A tuple with a composite identifier for a `TagChange.Tag`.
  """
  @type tag_change_tag_id :: {tag_change_id(), tag_id()}

  # Accepts a list of `TagChanges.TagChange` IDs.
  @spec mass_revert([tag_change_id()], Users.principal()) :: mass_revert_result()
  def mass_revert(tag_change_ids, principal) do
    tag_change_ids
    |> Map.new(&{&1, nil})
    |> mass_revert_impl(principal)
  end

  # Accepts a list of `TagChanges.Tag` IDs.
  @spec mass_revert_tags([tag_change_tag_id()], Users.principal()) :: mass_revert_result()
  def mass_revert_tags(tag_change_tag_ids, principal) do
    tag_change_tag_ids
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> mass_revert_impl(principal)
  end

  @spec mass_revert_impl(%{tag_change_id() => [tag_id()] | nil}, Users.principal()) ::
          mass_revert_result()
  defp mass_revert_impl(input, principal) do
    # Load the requested tag changes from the DB. `nil` in the position of the
    # tag IDs list means we want to revert all tags for that tag change.
    input =
      input
      |> Enum.map(fn {tc_id, tag_ids} ->
        %{
          tc_id: tc_id,
          tag_ids: if(not is_nil(tag_ids), do: tag_ids |> Enum.uniq())
        }
      end)

    tags_by_image =
      Repo.all(
        from tc in TagChange,
          inner_join:
            input in fragment(
              "SELECT * FROM jsonb_to_recordset(?) AS (tc_id int, tag_ids int[])",
              ^input
            ),
          on: tc.id == input.tc_id,
          inner_join: tct in TagChanges.Tag,
          on: tc.id == tct.tag_change_id,
          where: is_nil(input.tag_ids) or tct.tag_id in input.tag_ids,
          group_by: [tc.image_id, tct.tag_id],
          # Get min/max rows without subqueries (don't repeat this at home).
          # Retain only changes that dont cancel themselves out already i.e. we
          # want to ignore change sequences where the first change adds the tag
          # and the last change removes it or vice versa, because they are
          # already self-cancelling.
          having:
            fragment("(array_agg(? ORDER BY ? ASC))[1]", tct.added, tc.id) ==
              fragment("(array_agg(? ORDER BY ? DESC))[1]", tct.added, tc.id),
          select: %{
            image_id: tc.image_id,
            tag_id: tct.tag_id,
            last_change:
              fragment("(array_agg(row (?, ?) ORDER BY ? DESC))[1]", tc.id, tct.added, tc.id)
          }
      )
      |> Enum.group_by(& &1.image_id)

    # Load latest tag change IDs for each {image, tags} we are interested in.
    # We'll use this to filter out tag changes that are non-current, meaning
    # reverting them would not be useful as they were already overwritten by
    # some other change not in the list of reverted changes.
    input =
      tags_by_image
      |> Enum.map(fn {image_id, tags} ->
        %{
          image_id: image_id,
          tag_ids: tags |> Enum.map(& &1.tag_id)
        }
      end)

    latest_tc_ids =
      Repo.all(
        from tc in TagChange,
          inner_join:
            input in fragment(
              "SELECT * FROM jsonb_to_recordset(?) AS (image_id int, tag_ids int[])",
              ^input
            ),
          on: tc.image_id == input.image_id,
          inner_join: tct in TagChanges.Tag,
          on: tc.id == tct.tag_change_id and tct.tag_id in input.tag_ids,
          group_by: [tc.image_id, tct.tag_id],
          select: max(tc.id),
          # It's possible for the same tag change to cover the latest versions
          # of several tags, so deduplicate the results.
          distinct: true
      )
      |> MapSet.new()

    # Calculate the revert operations for each image.
    reverts_per_image =
      tags_by_image
      |> Enum.map(fn {image_id, tags} ->
        {added_tags, removed_tags} =
          tags
          |> Enum.filter(fn %{last_change: {tc_id, _}} -> tc_id in latest_tc_ids end)
          |> Enum.split_with(fn %{last_change: {_, added}} -> added end)

        # We send removed tags to be added, and added to be removed. That's how reverting works!
        %{
          image_id: image_id,
          added_tag_ids: Enum.map(removed_tags, & &1.tag_id),
          removed_tag_ids: Enum.map(added_tags, & &1.tag_id)
        }
      end)
      |> Enum.reject(&(&1.added_tag_ids == [] and &1.removed_tag_ids == []))

    with {:ok, {total_tags_affected, _}} <- Images.batch_update(reverts_per_image, principal) do
      {:ok, total_tags_affected}
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
      |> order_by(desc: :created_at, desc: :id)

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
