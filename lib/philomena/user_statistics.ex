defmodule Philomena.UserStatistics do
  @moduledoc """
  Atomic daily counters derived from user activity.

  This module performs no authorization. It accepts a statistic key, and
  updates the user's lifetime counter and UTC daily row together.
  """

  alias Philomena.Multi
  alias Philomena.Users
  alias Philomena.Users.User
  alias Philomena.UserStatistics.UserStatistic

  @permitted_actions [
    :images_count,
    :image_faves_count,
    :comments_count,
    :image_votes_count,
    :metadata_updates_count,
    :posts_count,
    :topics_count
  ]

  @typedoc "A daily and lifetime counter owned by this context."
  @type statistic ::
          :images_count
          | :image_faves_count
          | :comments_count
          | :image_votes_count
          | :metadata_updates_count
          | :posts_count
          | :topics_count

  @doc """
  Adds an atomic statistic increment to `multi`.

  The Multi updates both the user's lifetime counter and current UTC-daily
  counter. Passing `nil` leaves the Multi unchanged, which supports anonymous
  activity. The user reindex job is inserted with the transaction.

  ## Example

      iex> Multi.new() |> put_increment(user, :images_count, 2)
      %Multi{}

  """
  @spec put_increment(
          multi :: Multi.t(),
          user_or_id_or_nil_or_callback ::
            User.t() | integer() | nil | (Multi.changes() -> User.t() | integer() | nil),
          statistic :: statistic(),
          amount :: integer()
        ) ::
          Multi.t()
  def put_increment(multi, user_or_id_or_nil_or_callback, statistic, amount \\ 1)

  def put_increment(multi, nil, statistic, amount)
      when statistic in @permitted_actions and is_integer(amount),
      do: multi

  def put_increment(multi, %User{} = user, statistic, amount)
      when statistic in @permitted_actions and is_integer(amount),
      do: put_increment(multi, user.id, statistic, amount)

  def put_increment(multi, callback, statistic, amount)
      when is_function(callback, 1) and statistic in @permitted_actions and is_integer(amount) do
    Multi.merge(multi, fn changes ->
      put_increment(Multi.new(), callback.(changes), statistic, amount)
    end)
  end

  def put_increment(multi, user_id, statistic, amount)
      when is_integer(user_id) and statistic in @permitted_actions and is_integer(amount) do
    counter_step = {:put_increment_counter, make_ref()}

    multi
    |> Users.put_increment_counter(counter_step, user_id, statistic, amount)
    |> Multi.run({:put_increment, make_ref()}, fn repo, %{^counter_step => {count, nil}} ->
      if count == 1 do
        repo.insert(
          Map.put(%UserStatistic{day: Date.utc_today(), user_id: user_id}, statistic, amount),
          on_conflict: [inc: [{statistic, amount}]],
          conflict_target: [:day, :user_id]
        )
      else
        {:error, :not_found}
      end
    end)
  end

  @doc """
  Adds atomic increments for multiple users to `multi`.

  Every distinct user in `users_or_ids` receives the same lifetime and current
  UTC-daily increment. The updates use one query per table, and users are
  reindexed only after the owning Multi commits. An empty list leaves the Multi
  unchanged.

  ## Example

      iex> Multi.new() |> put_bulk_increment([user_a, user_b], :image_votes_count)
      %Multi{}

  """
  @spec put_bulk_increment(
          multi :: Multi.t(),
          users_or_ids :: [User.t() | integer()],
          statistic :: statistic(),
          amount :: integer()
        ) :: Multi.t()
  def put_bulk_increment(multi, users_or_ids, statistic, amount \\ 1)

  def put_bulk_increment(multi, [], statistic, amount)
      when statistic in @permitted_actions and is_integer(amount),
      do: multi

  def put_bulk_increment(multi, users_or_ids, statistic, amount)
      when is_list(users_or_ids) and statistic in @permitted_actions and is_integer(amount) do
    user_ids =
      users_or_ids
      |> Enum.map(fn
        %User{id: user_id} -> user_id
        user_id when is_integer(user_id) -> user_id
      end)
      |> Enum.uniq()

    counter_step = {:put_bulk_increment_counter, make_ref()}

    multi
    |> Users.put_increment_counters(counter_step, user_ids, statistic, amount)
    |> Multi.run({:put_bulk_increment, make_ref()}, fn repo, %{^counter_step => {count, nil}} ->
      if count == length(user_ids) do
        entries =
          Enum.map(user_ids, fn user_id ->
            %{day: Date.utc_today(), user_id: user_id}
            |> Map.put(statistic, amount)
          end)

        repo.insert_all(UserStatistic, entries,
          on_conflict: [inc: [{statistic, amount}]],
          conflict_target: [:day, :user_id]
        )

        {:ok, nil}
      else
        {:error, :not_found}
      end
    end)
  end
end
