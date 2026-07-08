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
end
