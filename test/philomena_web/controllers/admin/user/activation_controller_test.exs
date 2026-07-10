defmodule PhilomenaWeb.Admin.User.ActivationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only: the Users context only enqueues (dead) reindex jobs, and
  # moderation_log/2 is a synchronous Repo.insert.

  import Philomena.UsersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: every Admin.User.* child controller now gates on `can?(:edit, %User{})`,
  # matching the parent Admin.UserController edit form. A plain moderator does
  # NOT have `:edit` on User (that is admin-only, or a `%{"User" => %{"moderator"}}`
  # role_map grant - ability.ex "Manage users"), so plain moderators are denied
  # these destructive actions. Only admins (and User-role_map moderators) may
  # (de)activate, verify, unlock, reset API keys, force filters, wipe, or erase.

  describe "POST /admin/users/:user_id/activation (reactivate) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = deactivated_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/activation")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = deactivated_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/users/#{target.slug}/activation")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/users/:user_id/activation (reactivate)" do
    setup [:register_and_log_in_admin]

    test "reactivates a deactivated user and redirects to their profile", %{conn: conn} do
      target = deactivated_user_fixture()
      assert Repo.get(User, target.id).deleted_at != nil

      conn = post(conn, ~p"/admin/users/#{target.slug}/activation")

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "reactivated"
      assert Repo.get(User, target.id).deleted_at == nil
    end

    # NOTE: load_resource (not load_and_authorize) with persisted: true assigns
    # nil for an unknown slug, and Canary runs its not_found handler only for
    # :show/:edit/:update/:delete - NOT for :create. So on this :create action
    # the nil passes through and Users.reactivate_user(nil) raises
    # FunctionClauseError (nil-pass-through family), whereas the sibling :delete
    # action below redirects with the not-found flash for the same input.
    test "raises for an unknown slug", %{conn: conn} do
      assert_raise FunctionClauseError,
                   ~r/no function clause matching in Philomena\.Users\.reactivate_user\/1/,
                   fn ->
                     post(conn, ~p"/admin/users/no-such-user/activation")
                   end
    end
  end

  describe "POST /admin/users/:user_id/activation (reactivate) as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is denied to a plain moderator", %{conn: conn} do
      target = deactivated_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/activation")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      # unchanged: the account stays deactivated
      assert Repo.get(User, target.id).deleted_at != nil
    end
  end

  # NOTE: a moderator granted the `%{"User" => %{"moderator" => _}}` role_map
  # (ability.ex "Manage users") passes the same `can?(:edit, %User{})` gate as an
  # admin, so the privilege-escalation fix does not over-restrict them. Guards
  # against "fixing" the fix by over-tightening the gate. See
  # register_and_log_in_user_role_moderator/1.
  describe "POST /admin/users/:user_id/activation (reactivate) as a User-role moderator" do
    setup [:register_and_log_in_user_role_moderator]

    test "is allowed for a moderator granted the User role", %{conn: conn} do
      target = deactivated_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/activation")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Repo.get(User, target.id).deleted_at == nil
    end
  end

  describe "DELETE /admin/users/:user_id/activation (deactivate) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/activation")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/activation")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "DELETE /admin/users/:user_id/activation (deactivate)" do
    setup [:register_and_log_in_admin]

    test "deactivates an active user and records the actor", %{conn: conn, user: admin} do
      target = confirmed_user_fixture()
      assert Repo.get(User, target.id).deleted_at == nil

      conn = delete(conn, ~p"/admin/users/#{target.slug}/activation")

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "deactivated"

      reloaded = Repo.get(User, target.id)
      assert reloaded.deleted_at != nil
      assert reloaded.deleted_by_user_id == admin.id
    end

    # NOTE: unlike the :create sibling above, Canary's not_found handler DOES
    # run on this :delete action, so an unknown slug redirects to "/" with the
    # generic not-found flash instead of crashing.
    test "redirects for an unknown slug", %{conn: conn} do
      conn = delete(conn, ~p"/admin/users/no-such-user/activation")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /admin/users/:user_id/activation (deactivate) as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is denied to a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/activation")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."

      # unchanged: the account stays active
      reloaded = Repo.get(User, target.id)
      assert reloaded.deleted_at == nil
      assert reloaded.deleted_by_user_id == nil
    end
  end
end
