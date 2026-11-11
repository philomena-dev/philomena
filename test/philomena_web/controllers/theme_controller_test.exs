defmodule PhilomenaWeb.ThemeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users.Settings

  describe "GET /themes" do
    test "maps every theme to the stylesheet of its color, which holds both modes", %{conn: conn} do
      conn = get(conn, ~p"/themes")
      response = json_response(conn, 200)

      assert Map.keys(response) == Enum.sort(Settings.themes())
      assert response["dark-purple"] == "/css/purple.css"
      assert response["light-purple"] == "/css/purple.css"

      assert response |> Map.values() |> Enum.uniq() |> Enum.sort() ==
               Enum.map(~w(blue gray green orange pink purple red teal yellow), &"/css/#{&1}.css")
    end
  end
end
