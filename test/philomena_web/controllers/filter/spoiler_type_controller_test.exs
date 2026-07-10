defmodule PhilomenaWeb.Filter.SpoilerTypeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Repo

  test "anonymous PATCH redirects to the login page", %{conn: conn} do
    conn = patch(conn, ~p"/filters/spoiler_type")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "PATCH updates the spoiler type and redirects to the referrer default",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    assert user.spoiler_type == "static"

    conn = patch(conn, ~p"/filters/spoiler_type", %{"user" => %{"spoiler_type" => "click"}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Changed spoiler type to click"
    assert Repo.reload!(user).spoiler_type == "click"
  end

  test "PATCH redirects to the Referer header when present", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn =
      conn
      |> put_req_header("referer", "http://www.example.com/filters")
      |> patch(~p"/filters/spoiler_type", %{"user" => %{"spoiler_type" => "hover"}})

    assert redirected_to(conn) == "http://www.example.com/filters"
  end

  test "PUT is routed to the same action", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    conn = put(conn, ~p"/filters/spoiler_type", %{"user" => %{"spoiler_type" => "off"}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Changed spoiler type to off"
    assert Repo.reload!(user).spoiler_type == "off"
  end

  test "PATCH with an invalid spoiler type redirects with the failure flash", %{conn: conn} do
    # NOTE: an invalid spoiler_type now redirects to the referrer with the
    # failure flash rather than raising MatchError.
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    conn = patch(conn, ~p"/filters/spoiler_type", %{"user" => %{"spoiler_type" => "bogus"}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Couldn't change spoiler type!"
    assert Repo.reload!(user).spoiler_type == "static"
  end

  test "PATCH without user params redirects with the failure flash", %{conn: conn} do
    # NOTE: a request without the user param takes the fallback update/2 clause
    # and redirects with the failure flash rather than raising ActionClauseError.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = patch(conn, ~p"/filters/spoiler_type")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Couldn't change spoiler type!"
  end
end
