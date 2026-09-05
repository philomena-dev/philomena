defmodule Philomena.UserStatisticsTest do
  use Philomena.DataCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Multi
  alias Philomena.Repo
  alias Philomena.Users.User
  alias Philomena.UserStatistics
  alias Philomena.UserStatistics.UserStatistic

  defp transact_increment(user_or_id, statistic, amount \\ 1) do
    Multi.new()
    |> UserStatistics.put_increment(user_or_id, statistic, amount)
    |> Multi.transact()
  end

  test "increments a loaded user's lifetime and current UTC-day counters" do
    user = confirmed_user_fixture()

    assert {:ok, _changes} = transact_increment(user, :images_count)

    assert Repo.get!(User, user.id).images_count == 1

    assert %UserStatistic{images_count: 1, day: day} =
             Repo.get_by!(UserStatistic, user_id: user.id)

    assert day == Date.utc_today()
  end

  test "accepts an ID and negative amounts" do
    user = confirmed_user_fixture()

    assert {:ok, _changes} = transact_increment(user.id, :comments_count, 4)
    assert {:ok, _changes} = transact_increment(user.id, :comments_count, -2)

    assert Repo.get!(User, user.id).comments_count == 2
    assert Repo.get_by!(UserStatistic, user_id: user.id).comments_count == 2
  end

  test "nil users are a no-op for anonymous activity" do
    assert {:ok, _changes} = transact_increment(nil, :comments_count)
    assert Repo.aggregate(UserStatistic, :count) == 0
  end

  test "a missing user ID is not-found and creates no daily row" do
    assert {:error, _step, :not_found, _changes} =
             transact_increment(2_000_000_000, :posts_count)

    assert Repo.aggregate(UserStatistic, :count) == 0
  end

  test "unknown keys and non-integer amounts do not match the transactional API" do
    user = confirmed_user_fixture()

    assert_raise FunctionClauseError, fn ->
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(UserStatistics, :put_increment, [Multi.new(), user, :email, 1])
    end

    assert_raise FunctionClauseError, fn ->
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(UserStatistics, :put_increment, [Multi.new(), user, :images_count, 1.5])
    end
  end

  test "an owning transaction rollback restores both counters" do
    user = confirmed_user_fixture()

    assert {:error, :rollback, :forced_rollback, _changes} =
             Multi.new()
             |> UserStatistics.put_increment(user, :topics_count)
             |> Multi.run(:rollback, fn _repo, _changes -> {:error, :forced_rollback} end)
             |> Multi.transact()

    assert Repo.get!(User, user.id).topics_count == 0
    refute Repo.get_by(UserStatistic, user_id: user.id)
  end

  test "bulk increments update each distinct user in an owning Multi" do
    first = confirmed_user_fixture()
    second = confirmed_user_fixture()

    assert {:ok, _changes} =
             Multi.new()
             |> UserStatistics.put_bulk_increment([first, second, first.id], :image_votes_count)
             |> Multi.transact()

    for user <- [first, second] do
      assert Repo.get!(User, user.id).image_votes_count == 1
      assert Repo.get_by!(UserStatistic, user_id: user.id).image_votes_count == 1
    end
  end

  test "bulk increments roll back with their owning Multi" do
    user = confirmed_user_fixture()

    assert {:error, :rollback, :forced_rollback, _changes} =
             Multi.new()
             |> UserStatistics.put_bulk_increment([user], :posts_count)
             |> Multi.run(:rollback, fn _repo, _changes -> {:error, :forced_rollback} end)
             |> Multi.transact()

    assert Repo.get!(User, user.id).posts_count == 0
    refute Repo.get_by(UserStatistic, user_id: user.id)
  end

  test "daily rows cascade on user deletion and deleted IDs are not-found" do
    user = confirmed_user_fixture()
    assert {:ok, _changes} = transact_increment(user, :posts_count)

    Repo.delete!(user)

    refute Repo.get_by(UserStatistic, user_id: user.id)

    assert {:error, _step, :not_found, _changes} = transact_increment(user.id, :posts_count)
  end
end
