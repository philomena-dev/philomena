defmodule PhilomenaWeb.Admin.User.ForceFilterControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only.

  import Philomena.UsersFixtures
  import Philomena.FiltersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: gated on `can?(:edit, %User{})` (matching the parent edit form), which
  # a plain moderator lacks - so forcing/removing a forced filter, and even
  # rendering the force-filter form, is admin-only (or a User-role_map
  # moderator). The plug guards every action here (new/create/delete).

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

    # NOTE: the verify_authorized plug guards :new too, so a plain moderator no
    # longer even sees the force-filter form.
    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/users/#{target.slug}/force_filter/new")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: load_resource now uses required: true, so Canary's not_found handler
    # runs on :new too - an unknown slug redirects with the not-found flash
    # rather than passing nil into Users.change_user/1.
    test "redirects with the not-found flash for an unknown slug", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/users/no-such-user/force_filter/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
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

    # NOTE: load_resource now uses required: true, so Canary's not_found handler
    # runs on :create too - an unknown slug redirects with the not-found flash
    # rather than passing nil into Users.force_filter/2.
    test "redirects with the not-found flash for an unknown slug", %{conn: conn} do
      conn =
        post(conn, ~p"/admin/users/no-such-user/force_filter", %{
          "user" => %{"forced_filter_id" => 1}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "POST /admin/users/:user_id/force_filter (create) as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)

      conn =
        post(conn, ~p"/admin/users/#{target.slug}/force_filter", %{
          "user" => %{"forced_filter_id" => filter.id}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      # unchanged: no filter was forced
      assert Repo.get(User, target.id).forced_filter_id == nil
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

    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      filter = filter_fixture(target)
      {:ok, target} = Philomena.Users.force_filter(target, %{"forced_filter_id" => filter.id})

      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/force_filter")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      # unchanged: the forced filter remains in place
      assert Repo.get(User, target.id).forced_filter_id == filter.id
    end
  end
end
