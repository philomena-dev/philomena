defmodule PhilomenaWeb.Profile.Commission.ItemView do
  use PhilomenaWeb, :view

  alias Philomena.Commissions.Item

  def types, do: Item.types()
end
