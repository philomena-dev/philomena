defmodule Philomena.UserStatistics do
  @moduledoc """
  The UserStatistics context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.UserStatistics.UserStatistic
  alias Philomena.Users.User

  @permitted_actions [
    :images_count,
    :image_faves_count,
    :comments_count,
    :image_votes_count,
    :metadata_updates_count,
    :posts_count,
    :topics_count
  ]

  @doc """
  Updates a user statistic.

  ## Examples

      iex> inc_stat(user, :images_count, -1)
      {:ok, %UserStatistic{}}

  """
  def inc_stat(user_or_id, action, amount \\ 1)

  def inc_stat(nil, action, _amount) when action in @permitted_actions,
    do: {:ok, nil}

  def inc_stat(%User{} = user, action, amount)
      when action in @permitted_actions,
      do: inc_stat(user.id, action, amount)

  def inc_stat(user_id, action, amount)
      when action in @permitted_actions do
    now =
      DateTime.utc_now()
      |> DateTime.to_unix(:second)
      |> div(86400)

    user_query = where(User, id: ^user_id)

    Repo.transact(fn ->
      Repo.update_all(user_query, inc: [{action, amount}])

      Repo.insert(
        Map.put(%UserStatistic{day: now, user_id: user_id}, action, amount),
        on_conflict: [inc: [{action, amount}]],
        conflict_target: [:day, :user_id]
      )
    end)
  end
end
