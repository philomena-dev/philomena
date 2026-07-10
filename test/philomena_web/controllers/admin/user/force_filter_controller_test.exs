defmodule PhilomenaWeb.Admin.User.ForceFilterControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only.

  import Philomena.UsersFixtures
  import Philomena.FiltersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: gated on `can?(:index, User)`, so ANY moderator (not just admin) can
  # force or remove a forced filter.

  describe "GET /admin/users/:user_id/force_filter/new" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = get(conn, ~p"/admin/users/#{target.slug}/force_filter/new")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/users/#{target.slug}/force_filter/new")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for an admin", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/users/#{target.slug}/force_filter/new")
      assert html_response(conn, 200) =~ "Forcing filter for user"
    end

    test "renders the form for a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/users/#{target.slug}/force_filter/new")
      assert html_response(conn, 200) =~ "Forcing filter for user"
    end

    # NOTE: :new is not covered by Canary's not_found handler, so an unknown
    # slug passes nil through and Users.change_user(nil) raises
    # FunctionClauseError.
    test "raises for an unknown slug", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      assert_raise FunctionClauseError,
                   ~r/no function clause matching in Philomena\.Users\.change_user\/1/,
                   fn ->
                     get(conn, ~p"/admin/users/no-such-user/force_filter/new")
                   end
    end
  end

  describe "POST /admin/users/:user_id/force_filter (create) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter.id}
        })

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter.id}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/users/:user_id/force_filter (create)" do
    setup [:register_and_log_in_admin]

    test "forces the filter and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter.id}
        })

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Filter was forced"
      assert Repo.get(User, target.id).forced_filter_id == filter.id
    end

    # NOTE: force_filter_changeset only casts forced_filter_id with a
    # foreign_key_constraint; a nonexistent id fails the FK on update, returning
    # {:error, changeset}, and the controller's `{:ok, user} = ...` match raises
    # MatchError (no re-render branch) - the write action's failure path.
    test "raises MatchError on a nonexistent forced_filter_id", %{conn: conn} do
      target = confirmed_user_fixture()

      assert_raise MatchError,
                   ~r/no match of right hand side value:.*constraint_name: "users_forced_filter_id_fkey"/s,
                   fn ->
                     post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
                       "user" => %{"forced_filter_id" => 2_147_483_647}
                     })
                   end
    end

    # NOTE: :create is not covered by the not_found handler, so an unknown slug
    # passes nil through and Users.force_filter(nil, ...) raises
    # FunctionClauseError.
    test "raises for an unknown slug", %{conn: conn} do
      assert_raise FunctionClauseError,
                   ~r/no function clause matching in Philomena\.Users\.force_filter\/2/,
                   fn ->
                     post(conn, ~p"/admin/users/no-such-user/force_filter", %{
                       "user" => %{"forced_filter_id" => 1}
                     })
                   end
    end
  end

  describe "POST /admin/users/:user_id/force_filter (create) as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is allowed for a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter.id}
        })

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Repo.get(User, target.id).forced_filter_id == filter.id
    end
  end

  describe "DELETE /admin/users/:user_id/force_filter (delete)" do
    setup [:register_and_log_in_admin]

    test "removes the forced filter and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)
      {:ok, target} = Philomena.Users.force_filter(target, %{"forced_filter_id" => filter.id})
      assert target.forced_filter_id == filter.id

      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Forced filter was removed"
      assert Repo.get(User, target.id).forced_filter_id == nil
    end

    # NOTE: succeeds even when no filter is forced (unforce_filter_changeset just
    # sets forced_filter_id: nil unconditionally).
    test "still succeeds when no filter is forced", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Repo.get(User, target.id).forced_filter_id == nil
    end

    # NOTE: :delete runs the not_found handler, so an unknown slug redirects.
    test "redirects for an unknown slug", %{conn: conn} do
      conn = delete(conn, ~p"/admin/users/no-such-user/force_filter")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /admin/users/:user_id/force_filter (delete) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "is allowed for a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
    end
  end
end
