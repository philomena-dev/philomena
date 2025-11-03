defmodule PhilomenaWeb.CommissionView do
  use PhilomenaWeb, :view

  alias Philomena.Commissions.Commission
  alias Philomena.Commissions.Item

  def suggested_tags, do: [[key: "-", value: ""] | Commission.suggested_tags()]
  def types, do: Item.types()
end
