defmodule Philomena.AttributionFixtures do
  @moduledoc """
  Shared request attribution for fixtures.

  Several context `create_*` functions take an attribution keyword list in
  the shape built by `PhilomenaWeb.UserAttributionPlug` (`:ip`,
  `:fingerprint`, `:user`). This module centralizes that shape so fixtures
  stay consistent with each other (and with `Philomena.ImagesFixtures`,
  which hardcodes the same values on the image row).
  """

  @doc """
  Attribution keyword list for the given `user` (`nil` for anonymous).
  """
  def attribution(user \\ nil) do
    [
      ip: %Postgrex.INET{address: {203, 0, 113, 1}, netmask: 32},
      fingerprint: "d015c342859dde3",
      user: user
    ]
  end

  @doc """
  The same attribution as `attribution/1`, as the typed
  `Philomena.Attribution.Actor` struct that actor-first context functions
  take.
  """
  def actor(user \\ nil) do
    attrs = attribution(user)

    %Philomena.Attribution.Actor{
      ip: attrs[:ip],
      fingerprint: attrs[:fingerprint],
      user: attrs[:user]
    }
  end

  @doc """
  Clears the Valkey tag-change rate-limit counters for the given attribution.

  Tag changes authored through `Philomena.Images.update_tags/3` bump the
  `rltcn:`/`rltcr:` counters, which `Philomena.TagChanges.Limits` scopes to the
  acting identity: `u:<user_id>` for a logged-in user, `i:<ip>` for an anonymous
  visitor (50 tag changes / 1 rating change per 10 minutes for
  anonymous/unverified users). The SQL sandbox does not roll Valkey back, so the
  counters accumulate across test runs (10-minute TTL) and eventually trip the
  limit. Tests that author tag changes with the shared `attribution/1` fixture
  must reset it in setup.

  When the attribution carries a user, both the `u:` (its actual scope) and the
  `i:` variants are cleared defensively so the helper is useful regardless of
  which path a test exercises; an anonymous attribution clears only `i:`.
  """
  def reset_tag_change_limits(attrs \\ attribution()) do
    ip = attrs[:ip]

    keys =
      case attrs[:user] do
        nil ->
          ["rltcn:i:#{ip}", "rltcr:i:#{ip}"]

        user ->
          ["rltcn:u:#{user.id}", "rltcr:u:#{user.id}", "rltcn:i:#{ip}", "rltcr:i:#{ip}"]
      end

    Redix.command!(:redix, ["DEL" | keys])
    :ok
  end
end
