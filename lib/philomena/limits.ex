defmodule Philomena.Limits do
  @moduledoc """
  Global limits for users.
  """

  #
  # Tags changed per 10 minutes (50)
  #

  defp tag_count_key_for_ip(ip) do
    "rltcn:#{to_string(ip)}"
  end

  def is_limited_for_tag_count?(nil, ip) do
    amt = Redix.command!(:redix, ["GET", tag_count_key_for_ip(ip)]) || 0
    amt >= 50
  end

  def is_limited_for_tag_count?(_user, _ip), do: false

  def update_tag_count_after_update(nil, ip, amount) do
    Redix.pipeline!(:redix, [
      ["INCRBY", tag_count_key_for_ip(ip), amount],
      ["EXPIRE", tag_count_key_for_ip(ip), 10 * 60]
    ])
  end

  def update_tag_count_after_update(_user, _ip, _amount), do: nil

  #
  # Rating tags changed per 10 minutes (1)
  #

  defp rating_count_key_for_ip(ip) do
    "rltcr:#{to_string(ip)}"
  end

  def is_limited_for_rating_count?(nil, ip) do
    amt = Redix.command!(:redix, ["GET", rating_count_key_for_ip(ip)]) || 0
    amt >= 1
  end

  def is_limited_for_rating_count?(_user, _ip), do: false

  def update_rating_count_after_update(nil, ip, amount) do
    Redix.pipeline!(:redix, [
      ["INCRBY", rating_count_key_for_ip(ip), amount],
      ["EXPIRE", rating_count_key_for_ip(ip), 10 * 60]
    ])
  end

  def update_rating_count_after_update(_user, _ip, _amount), do: nil
end
