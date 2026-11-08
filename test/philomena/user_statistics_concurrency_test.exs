defmodule Philomena.UserStatisticsConcurrencyTest do
  use Philomena.ConcurrentDataCase

  import Philomena.UsersFixtures

  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.UserStatistics
  alias Philomena.UserStatistics.UserStatistic
  alias Philomena.Users.User

  test "atomic increments do not lose updates from concurrent callers" do
    user = confirmed_user_fixture()

    results =
      concurrently(
        for _ <- 1..8 do
          fn ->
            Multi.new()
            |> UserStatistics.put_increment(user.id, :image_votes_count)
            |> Multi.transact()
          end
        end
      )

    assert Enum.all?(results, &match?({:ok, _}, &1))
    assert Repo.get!(User, user.id).image_votes_count == 8
    assert Repo.get_by!(UserStatistic, user_id: user.id).image_votes_count == 8
  end
end
