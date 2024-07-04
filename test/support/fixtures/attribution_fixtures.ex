defmodule Philomena.AttributionFixtures do
  @moduledoc """
  This module defines test helpers for creating attribution.
  """

  def attribution_fixture(user \\ nil) do
    {:ok, ip} = EctoNetwork.INET.cast("127.0.0.1")
    fingerprint = to_string(:io_lib.format(~c"d~14.16.0b", [:rand.uniform(2 ** 53)]))

    [
      ip: ip,
      fingerprint: fingerprint,
      referrer: "",
      user: user,
      user_agent: ""
    ]
  end
end
