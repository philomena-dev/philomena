defmodule PhilomenaWeb.ImageFilterPlugTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Philomena.Attribution.Actor
  alias Philomena.Filters.Filter
  alias Philomena.Filters.ImageFilter
  alias PhilomenaWeb.ImageFilterPlug

  @actor %Actor{ip: %Postgrex.INET{address: {203, 0, 113, 1}, netmask: 32}}

  test "assigns the compiled domain filter state" do
    conn =
      conn(:get, "/")
      |> assign(:actor, @actor)
      |> assign(:current_filter, %Filter{})
      |> assign(:forced_filter, nil)
      |> ImageFilterPlug.call([])

    assert %ImageFilter{} = conn.assigns.image_filter
    refute conn.halted
  end

  test "assigns an all-hidden filter for an invalid stored filter" do
    conn =
      conn(:get, "/")
      |> assign(:actor, @actor)
      |> assign(:current_filter, %Filter{hidden_complex_str: "("})
      |> assign(:forced_filter, nil)
      |> ImageFilterPlug.call([])

    refute conn.halted
    assert conn.assigns.image_filter.query == %{match_all: %{}}
    assert conn.assigns.image_filter.display_query == %{match_all: %{}}
  end
end
