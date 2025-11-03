defmodule PhilomenaWeb.Profile.CommissionView do
  use PhilomenaWeb, :view

  alias Philomena.Commissions.Commission

  def suggested_tags, do: Commission.suggested_tags()

  def current?(%{id: id}, %{id: id}), do: true
  def current?(_user1, _user2), do: false
end
