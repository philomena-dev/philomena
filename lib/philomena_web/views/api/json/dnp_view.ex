defmodule PhilomenaWeb.Api.Json.DnpView do
  use PhilomenaWeb, :view

  def render("dnp.json", %{dnp: dnp}) do
    %{
      id: dnp.id,
      dnp_type: dnp.dnp_type,
      conditions: dnp.conditions,
      reason: if(!dnp.hide_reason, do: dnp.reason),
      created_at: dnp.created_at
    }
  end
end
