defmodule Philomena.TagChanges.LimitsTest do
  # async: false because these counters live in Valkey, NOT Postgres: the Ecto
  # SQL sandbox does not roll them back and they carry a 10-minute TTL. Every
  # test therefore uses a fresh user id / IP and clears its own keys in an
  # on_exit callback so nothing leaks into a later test or a later `mix test`
  # run (see KNOWN-ODDITIES.md, "Tag-change rate limits live outside the
  # database").
  use Philomena.DataCase, async: false

  import Philomena.AttributionFixtures

  alias Philomena.TagChanges.Limits
  alias Philomena.Users.User

  # The limit constants from Philomena.TagChanges.Limits. `check_limit/4`
  # compares `amt + additional > limit`, so the boundary is inclusive: a change
  # that lands the total exactly ON the limit is permitted, and only one that
  # would carry it past the limit is refused. The effective tag allowance is the
  # full 50, matching the advertised maximum; the tests below pin that boundary.
  @tag_limit 50
  @rating_limit 1

  # Lightweight, DB-free actors. Limits only reads `user.id` (for the scope key)
  # and `user.verified` (for the exemption), and touches Valkey via Redix - it
  # never hits Postgres - so a bare struct with a unique id is enough and keeps
  # the counters isolated per test.
  defp unverified_user, do: %User{id: System.unique_integer([:positive]), verified: false}
  defp verified_user, do: %User{id: System.unique_integer([:positive]), verified: true}

  defp unique_ip do
    n = System.unique_integer([:positive])
    %Postgrex.INET{address: {203, 0, rem(div(n, 254), 254) + 1, rem(n, 254) + 1}, netmask: 32}
  end

  # Register cleanup of every counter key an actor could have touched.
  defp track(user, ip) do
    on_exit(fn -> reset_tag_change_limits(user: user, ip: ip) end)
  end

  defp raw_tag_count(user) do
    Redix.command!(:redix, ["GET", "rltcn:u:#{user.id}"])
  end

  describe "tag-change limit scoping (regression: shared IP, independent buckets)" do
    test "two different unverified users on the same IP get independent buckets" do
      ip = unique_ip()
      user_a = unverified_user()
      user_b = unverified_user()
      track(user_a, ip)
      track(user_b, ip)

      # Fill user A's tag bucket to the limit; the bucket now sits exactly at 50.
      Limits.update_tag_count_after_update(user_a, ip, @tag_limit)

      # A's next change is refused: `50 + 1 > 50`. (The bucket is at the limit,
      # so it is the pending change that trips it - the form production uses.)
      assert Limits.limited_for_tag_count?(user_a, ip, 1)

      # ...but B, sharing the very same IP, is untouched. This is the assertion
      # that would have caught the pre-fix behavior, where the counter was keyed
      # on IP alone and A would have locked B out.
      refute Limits.limited_for_tag_count?(user_b, ip)
    end

    test "the same user is limited regardless of which IP they act from" do
      ip1 = unique_ip()
      ip2 = unique_ip()
      user = unverified_user()
      track(user, ip1)
      track(user, ip2)

      Limits.update_tag_count_after_update(user, ip1, @tag_limit)

      # Keyed by user id, so with the bucket at the limit the next change from a
      # completely different IP is still refused (`50 + 1 > 50`).
      assert Limits.limited_for_tag_count?(user, ip2, 1)
    end
  end

  describe "anonymous actors are keyed by IP" do
    test "two anonymous requests from the same IP share a bucket" do
      ip = unique_ip()
      track(nil, ip)

      refute Limits.limited_for_tag_count?(nil, ip)

      # Fill the shared IP bucket to the limit; the next change is then refused.
      Limits.update_tag_count_after_update(nil, ip, @tag_limit)

      assert Limits.limited_for_tag_count?(nil, ip, 1)
    end

    test "anonymous requests from different IPs do not share a bucket" do
      ip1 = unique_ip()
      ip2 = unique_ip()
      track(nil, ip1)
      track(nil, ip2)

      # Fill ip1's bucket to the limit; its next change is refused, ip2 untouched.
      Limits.update_tag_count_after_update(nil, ip1, @tag_limit)

      assert Limits.limited_for_tag_count?(nil, ip1, 1)
      refute Limits.limited_for_tag_count?(nil, ip2)
    end
  end

  describe "tag-change limit boundary" do
    test "the change landing exactly on the limit is allowed; the one past it is refused" do
      ip = unique_ip()
      user = unverified_user()
      track(user, ip)

      # 49 successful tag changes so far.
      Limits.update_tag_count_after_update(user, ip, @tag_limit - 1)

      # NOTE: the boundary is inclusive. `check_limit/4` compares
      # `amt + additional > limit`, so a change reaching exactly `limit` (50) is
      # allowed and only one that would exceed it is refused. At amt=49 a pending
      # change of 1 lands the total on 50 (`49 + 1 > 50` is false → allowed), but
      # a pending change of 2 would overshoot to 51 (`49 + 2 > 50` → refused).
      refute Limits.limited_for_tag_count?(user, ip)
      refute Limits.limited_for_tag_count?(user, ip, 0)
      refute Limits.limited_for_tag_count?(user, ip, 1)
      assert Limits.limited_for_tag_count?(user, ip, 2)
    end

    test "a counter sitting exactly on the limit refuses any further change but is not itself over" do
      ip = unique_ip()
      user = unverified_user()
      track(user, ip)

      # Drive the counter to exactly the limit (50).
      Limits.update_tag_count_after_update(user, ip, @tag_limit)

      # NOTE: a bare over-check at exactly the limit is NOT limited - `50 > 50` is
      # false - so `additional = 0` reports "not over". But any pending change of
      # 1 would push past the limit (`50 + 1 > 50`), so the next change is refused.
      refute Limits.limited_for_tag_count?(user, ip, 0)
      assert Limits.limited_for_tag_count?(user, ip, 1)
    end
  end

  describe "verified users are exempt" do
    test "a verified user is never limited and no counter is recorded for them" do
      ip = unique_ip()
      user = verified_user()
      track(user, ip)

      # Even a massive increment is a no-op for a verified user.
      Limits.update_tag_count_after_update(user, ip, @tag_limit * 10)

      refute Limits.limited_for_tag_count?(user, ip)

      # increment_counter/4 short-circuits on `considered_for_limit?/1`, so
      # nothing was ever written to Valkey.
      assert is_nil(raw_tag_count(user))
    end
  end

  describe "rating-change limit scoping" do
    test "one rating change exhausts an unverified user's bucket without affecting others" do
      ip = unique_ip()
      user_a = unverified_user()
      user_b = unverified_user()
      track(user_a, ip)
      track(user_b, ip)

      refute Limits.limited_for_rating_count?(user_a, ip)

      # @rating_changes_per_ten_minutes is 1, so a single change trips it.
      Limits.update_rating_count_after_update(user_a, ip, @rating_limit)

      assert Limits.limited_for_rating_count?(user_a, ip)

      # A different user on the same IP keeps their own (empty) bucket.
      refute Limits.limited_for_rating_count?(user_b, ip)
    end

    test "anonymous rating changes are keyed by IP" do
      ip1 = unique_ip()
      ip2 = unique_ip()
      track(nil, ip1)
      track(nil, ip2)

      Limits.update_rating_count_after_update(nil, ip1, @rating_limit)

      assert Limits.limited_for_rating_count?(nil, ip1)
      refute Limits.limited_for_rating_count?(nil, ip2)
    end

    test "a verified user's rating changes are never limited or recorded" do
      ip = unique_ip()
      user = verified_user()
      track(user, ip)

      Limits.update_rating_count_after_update(user, ip, @rating_limit * 10)

      refute Limits.limited_for_rating_count?(user, ip)
      assert is_nil(Redix.command!(:redix, ["GET", "rltcr:u:#{user.id}"]))
    end
  end
end
