defmodule PhilomenaWeb.ThemeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users.User

  describe "GET /themes" do
    test "returns a JSON map of theme names to stylesheet paths", %{conn: conn} do
      conn = get(conn, ~p"/themes")
      response = json_response(conn, 200)

      assert response == Map.new(User.themes(), &{&1, "/css/#{&1}.css"})
    end
  end
end
