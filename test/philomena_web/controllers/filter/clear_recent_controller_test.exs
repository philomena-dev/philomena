defmodule PhilomenaWeb.Filter.ClearRecentControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.FiltersFixtures

  alias Philomena.Repo
  alias Philomena.Users
  alias Philomena.Users.User

  describe "DELETE /filters/clear_recent" do
    test "anonymous users are redirected with the sign-in flash", %{conn: conn} do
      conn = delete(conn, ~p"/filters/clear_recent")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must be signed in to see this page."
    end

    test "resets the recent filter list to the current filter", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      old_filter = filter_fixture(user)
      filter = filter_fixture(user)
      {:ok, user} = Users.update_filter(user, old_filter)
      {:ok, user} = Users.update_filter(user, filter)
      assert user.recent_filter_ids == [filter.id, old_filter.id]

      conn = delete(conn, ~p"/filters/clear_recent")

      assert redirected_to(conn) == ~p"/filters"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Cleared recent filters."
      assert Repo.get!(User, user.id).recent_filter_ids == [filter.id]
    end
  end
end
