defmodule PhilomenaWeb.OpensearchView do
  use PhilomenaWeb, :view

  alias Philomena.Configs

  def site_name(), do: Configs.get("site_name")
  def site_url(), do: Configs.get("site_url")
end
