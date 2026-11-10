defmodule PhilomenaWeb.SettingViewTest do
  use PhilomenaWeb.ConnCase, async: true

  alias PhilomenaWeb.SettingView

  defp tab_link(conn, tab_id, opts \\ []) do
    conn
    |> SettingView.tab_link("Name", tab_id, opts)
    |> Phoenix.HTML.safe_to_string()
  end

  describe "settings tabs" do
    test "the default tab and its panel are selected when no tab is requested", %{conn: conn} do
      conn = %{conn | params: %{}}

      assert tab_link(conn, "watched", default: true) =~ ~s(class="tab selected")
      assert SettingView.tab_class(conn, "watched", default: true) == "selected"
      assert tab_link(conn, "display") =~ ~s(class="tab")
      assert SettingView.tab_class(conn, "display") == nil
    end

    test "the requested tab and its panel are selected instead of the default", %{conn: conn} do
      conn = %{conn | params: %{"tab" => "display"}}

      assert tab_link(conn, "display") =~ ~s(class="tab selected")
      assert SettingView.tab_class(conn, "display") == "selected"
      assert SettingView.tab_class(conn, "watched", default: true) == nil
    end
  end
end
