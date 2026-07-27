defmodule Philomena.TagChanges do
  @moduledoc """
  The TagChanges context.
  """

  import Ecto.Query, warn: false
  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Repo
  alias PhilomenaQuery.Parse.IpParser
  alias PhilomenaQuery.Search
  alias Philomena.Attribution.Actor
  alias Philomena.IntegerId
  alias Philomena.ModerationLogs
  alias Philomena.ModerationLogs.Paths
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

  @doc """
  Reverts the tag changes named by `ids` on behalf of `actor`.

  Changes on images hidden from users are silently skipped, and an empty or
  fully-skipped list is a successful reversion of zero changes.

  Returns `{:ok, reverted_tag_changes}`, `{:error, :unauthorized}`, or
  `{:error, :invalid_ids}` when `ids` is not a list. Failures inside the
  batch update surface as their own `{:error, _}` shapes.
  """
  @spec revert_tag_changes(Actor.t(), any()) ::
          {:ok, [TagChange.t()]} | {:error, any()}
  def revert_tag_changes(%Actor{} = actor, ids) do
    with :ok <- authorize(actor, :revert, TagChange),
         {:ok, tag_changes} <- mass_revert_for(actor, ids) do
      ModerationLogs.create_moderation_log(
        actor.user,
        "TagChange.Revert:create",
        Paths.profile_path(actor.user),
        "Reverted #{length(tag_changes)} tag changes"
      )

      {:ok, tag_changes}
    end
  end

  defp mass_revert_for(actor, ids) when is_list(ids) do
    mass_revert(ids, %{
      ip: actor.ip,
      fingerprint: actor.fingerprint,
      user_id: actor.user.id
    })
  end

  defp mass_revert_for(_actor, _ids), do: {:error, :invalid_ids}

  # Accepts a list of TagChanges.TagChange IDs. This performs the actual reversion,
  # and performs no authorization or logging.
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
    # Reverting a set of changes means restoring the state from before the
    # earliest of them, so collapse each (image, tag) history to its earliest
    # record and invert that. `created_at` has second precision,
    # so ties are broken by tag change id.
    changes_per_image =
      tags
      |> Enum.group_by(& &1.tag_change.image_id)
      |> Enum.map(fn {image_id, instances} ->
        changed_tags =
          instances
          |> Enum.sort_by(&{DateTime.to_unix(&1.tag_change.created_at), &1.tag_change_id})
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

  @doc """
  Enqueues a background reversion of every tag change made by one identity,
  on behalf of `actor`.

  Returns `{:ok, target}`, `{:error, :unauthorized}`, or
  `{:error, :invalid_target}` when `params` names no target.
  """
  @spec full_revert(Actor.t(), map()) ::
          {:ok, map()} | {:error, :unauthorized | :invalid_target}
  def full_revert(%Actor{} = actor, params) do
    with :ok <- authorize(actor, :revert, TagChange),
         {:ok, target} <- full_revert_target(params) do
      attributes = %{
        ip: to_string(actor.ip),
        fingerprint: actor.fingerprint,
        user_id: actor.user.id,
        batch_size: 100
      }

      Exq.enqueue(Exq, "indexing", TagChangeRevertWorker, [
        Map.put(target, :attributes, attributes)
      ])

      log_full_revert(actor.user, target)

      {:ok, target}
    end
  end

  defp full_revert_target(%{"user_id" => user_id}), do: {:ok, %{user_id: user_id}}
  defp full_revert_target(%{"ip" => ip}), do: {:ok, %{ip: ip}}
  defp full_revert_target(%{"fingerprint" => fingerprint}), do: {:ok, %{fingerprint: fingerprint}}
  defp full_revert_target(_params), do: {:error, :invalid_target}

  defp log_full_revert(user, target) do
    {subject, subject_path} =
      case target do
        %{user_id: user_id} ->
          full_revert_log_user(user_id)

        %{ip: ip} ->
          {"ip #{ip}", Paths.ip_profile_path(ip)}

        %{fingerprint: fingerprint} ->
          {"fingerprint #{fingerprint}", Paths.fingerprint_profile_path(fingerprint)}
      end

    ModerationLogs.create_moderation_log(
      user,
      "TagChange.FullRevert:create",
      subject_path,
      "Reverted all tag changes for #{subject}"
    )
  end

  defp full_revert_log_user(user_id) do
    with {:ok, id} <- IntegerId.parse(user_id),
         %User{} = user <- Repo.get(User, id) do
      {"user #{user.name}", Paths.profile_path(user)}
    else
      _ -> {"user #{user_id}", "/tag_changes"}
    end
  end

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
  Deletes the tag change named by the raw request `id` from the history, on
  behalf of `actor` (a user, or `nil` for an anonymous visitor).

  An id that cannot name a row is `{:error, :not_found}`, while a well-formed id
  that names no row authorizes `nil` - which no rule permits - and is
  therefore `{:error, :unauthorized}`.

  ## Examples

      iex> delete_tag_change(moderator, "1")
      {:ok, %TagChange{}}

      iex> delete_tag_change(user, "1")
      {:error, :unauthorized}

      iex> delete_tag_change(moderator, "not-an-integer")
      {:error, :not_found}

  """
  @spec delete_tag_change(User.t() | nil, any()) ::
          {:ok, TagChange.t()}
          | {:error, :unauthorized | :not_found}
          | {:error, Ecto.Changeset.t()}
  def delete_tag_change(actor, id) do
    case IntegerId.parse(id) do
      {:ok, id} ->
        tag_change =
          TagChange
          |> preload([:user, :image, tags: [:tag]])
          |> Repo.get(id)

        with :ok <- authorize(actor, :delete, tag_change) do
          delete_loaded_tag_change(actor, tag_change)
        end

      :error ->
        {:error, :not_found}
    end
  end

  defp delete_loaded_tag_change(actor, %TagChange{} = tag_change) do
    case Repo.delete(tag_change) do
      {:ok, %TagChange{} = tc} = result ->
        Search.delete_document(tc.id, TagChange)
        log_tag_change_deletion(actor, tc)
        result

      result ->
        result
    end
  end

  defp log_tag_change_deletion(actor, %TagChange{user: user, image: image, tags: tags, ip: ip}) do
    name =
      case user do
        %{name: name} -> name
        _ -> to_string(ip)
      end

    ModerationLogs.create_moderation_log(
      actor,
      "TagChange:delete",
      Paths.image_path(image),
      "Deleted tag change by #{name} containing #{length(tags)} tags on image #{image.id} from history"
    )
  end

  @doc """
  Deletes tag changes that have no associated tags.
  ## Examples
      iex> delete_empty_tag_changes()
      {number_of_deleted_records, [%TagChange{}, ...]}
  """
  def delete_empty_tag_changes do
    {count, tag_changes} =
      TagChange
      |> from(as: :tag_change)
      |> where(
        not exists(where(TagChanges.Tag, [t], t.tag_change_id == parent_as(:tag_change).id))
      )
      |> select([tc], tc)
      |> Repo.delete_all()

    Enum.each(tag_changes, &Search.delete_document(&1.id, TagChange))

    {count, tag_changes}
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
            must: [query | resource_filters(user, params)]
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

  defp resource_filters(user, %{"resource_type" => type, "resource_id" => id})
       when is_binary(type) and is_binary(id) and id != "" do
    [resource_filter(user, type, id)]
  end

  defp resource_filters(_user, _params), do: []

  # Term filters mirroring the fields each role may query through `tcq`
  # (see Philomena.TagChanges.Query): ip and fingerprint are moderator-only.
  # A recognized resource the requester may not filter by, or an invalid
  # value, matches nothing rather than silently listing everything.
  defp resource_filter(_user, "image", id), do: %{term: %{image_id: id}}
  defp resource_filter(_user, "tag", name), do: %{term: %{tag: String.downcase(name)}}
  defp resource_filter(_user, "user", name), do: %{term: %{user: String.downcase(name)}}

  defp resource_filter(%{role: role}, "ip", ip) when role in ~W(moderator admin) do
    case IpParser.parse(ip) do
      {:ok, _tokens, "", _, _, _} -> %{term: %{ip: ip}}
      _ -> %{match_none: %{}}
    end
  end

  defp resource_filter(%{role: role}, "fingerprint", fp) when role in ~W(moderator admin),
    do: %{term: %{fingerprint: fp}}

  defp resource_filter(_user, _type, _id), do: %{match_none: %{}}

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
