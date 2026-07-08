defmodule Philomena.CommissionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Commissions` context.
  """

  alias Philomena.Commissions

  @doc """
  Creates an open commission sheet for `user`.
  """
  def commission_fixture(user, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        information: "Test commission information",
        contact: "Test contact info",
        will_create: "Test subjects",
        open: true
      })

    {:ok, commission} = Commissions.create_commission(user, attrs)

    commission
  end

  @doc """
  Adds an item to `commission` (and bumps its `commission_items_count`,
  which the directory listing filters on).
  """
  def commission_item_fixture(commission, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        item_type: "Sketch",
        description: "Test item description",
        base_price: 20
      })

    {:ok, %{item: item}} = Commissions.create_item(commission, attrs)

    item
  end
end
