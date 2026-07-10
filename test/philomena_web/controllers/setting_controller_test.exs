defmodule PhilomenaWeb.SettingControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # The route is public: anonymous users get the local (cookie-backed)
  # settings only.

  alias Philomena.Repo

  describe "GET /settings/edit" do
    test "renders the form for anonymous users", %{conn: conn} do
      response = html_response(get(conn, ~p"/settings/edit"), 200)

      assert response =~ "Editing Settings - Derpibooru"
    end

    test "renders the form for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      response = html_response(get(conn, ~p"/settings/edit"), 200)

      assert response =~ "Editing Settings - Derpibooru"
    end
  end

  describe "PATCH /settings" do
    test "sets local-setting cookies for anonymous users", %{conn: conn} do
      conn =
        patch(conn, ~p"/settings", %{
          "user" => %{"hidpi" => "true", "webm" => "false"}
        })

      assert redirected_to(conn) == ~p"/settings/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Settings updated successfully."
      assert conn.resp_cookies["hidpi"].value == "true"
      assert conn.resp_cookies["webm"].value == "false"
    end

    test "updates user settings and sets cookies for logged-in users", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        patch(conn, ~p"/settings", %{
          "user" => %{
            "theme_name" => "light",
            "theme_color" => "orange",
            "images_per_page" => "30",
            "hidpi" => "true"
          }
        })

      assert redirected_to(conn) == ~p"/settings/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Settings updated successfully."
      assert conn.resp_cookies["hidpi"].value == "true"

      reloaded = Repo.reload!(user)
      assert reloaded.theme == "light-orange"
      assert reloaded.images_per_page == 30
    end

    test "PUT also updates settings", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        put(conn, ~p"/settings", %{
          "user" => %{"theme_name" => "dark", "theme_color" => "green"}
        })

      assert redirected_to(conn) == ~p"/settings/edit"
      assert Repo.reload!(user).theme == "dark-green"
    end

    test "falls back to dark-blue when only one theme component is submitted", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn = patch(conn, ~p"/settings", %{"user" => %{"theme_name" => "light"}})

      assert redirected_to(conn) == ~p"/settings/edit"
      assert Repo.reload!(user).theme == "dark-blue"
    end

    test "re-renders the form with the error flash for an invalid value", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn = patch(conn, ~p"/settings", %{"user" => %{"images_per_page" => "999"}})

      # the re-render is missing the :title assign (same shape as the other
      # UGC failure re-renders); pin the page heading instead
      response = html_response(conn, 200)
      assert response =~ "Content Settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Your settings could not be saved!"

      assert Repo.reload!(user).images_per_page == user.images_per_page
    end

    test "crashes when the user parameter is missing", %{conn: conn} do
      assert_raise Phoenix.ActionClauseError, fn ->
        patch(conn, ~p"/settings", %{})
      end
    end
  end
end
