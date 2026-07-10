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
  Clears the Valkey tag-change rate-limit counters for the shared attribution
  IP.

  Tag changes authored through `Philomena.Images.update_tags/3` bump the
  `rltcn:`/`rltcr:` counters keyed on the attribution IP (see
  `Philomena.TagChanges.Limits` - 50 tag changes per 10 minutes for
  anonymous/unverified users). The SQL sandbox does not roll Valkey back, so
  the counter accumulates across test runs (10-minute TTL) and eventually
  trips `{:error, :check_limits, :limit_exceeded, ...}`. Tests that author tag
  changes with the shared `attribution/1` fixture must reset it in setup.
  """
  def reset_tag_change_limits(attrs \\ attribution()) do
    ip = attrs[:ip]
    Redix.command!(:redix, ["DEL", "rltcn:#{ip}", "rltcr:#{ip}"])
    :ok
  end
end
