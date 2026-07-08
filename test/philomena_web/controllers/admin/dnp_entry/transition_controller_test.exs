defmodule PhilomenaWeb.Admin.DnpEntry.TransitionControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.DnpEntriesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Repo

  defp dnp_entry!(_context) do
    user = confirmed_user_fixture()
    tag = tag_fixture(name: "artist:transition-#{System.unique_integer([:positive])}")
    %{dnp_entry: dnp_entry_fixture(user, tag)}
  end

  describe "POST /admin/dnp_entries/:dnp_entry_id/transition authorization" do
    setup :dnp_entry!

    test "redirects anonymous users to login", %{conn: conn, dnp_entry: entry} do
      conn = post(conn, ~p"/admin/dnp_entries/#{entry}/transition", state: "claimed")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn, dnp_entry: entry} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/dnp_entries/#{entry}/transition", state: "claimed")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/dnp_entries/:dnp_entry_id/transition (create)" do
    setup [:register_and_log_in_moderator, :dnp_entry!]

    test "transitions the entry and redirects to it", %{conn: conn, dnp_entry: entry} do
      conn = post(conn, ~p"/admin/dnp_entries/#{entry}/transition", state: "claimed")
      assert redirected_to(conn) == ~p"/dnp/#{entry}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "updated"

      assert Repo.get(DnpEntry, entry.id).aasm_state == "claimed"
    end

    test "re-renders the error flash for an invalid target state", %{conn: conn, dnp_entry: entry} do
      conn = post(conn, ~p"/admin/dnp_entries/#{entry}/transition", state: "not-a-state")
      assert redirected_to(conn) == ~p"/dnp/#{entry}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Failed to update"

      assert Repo.get(DnpEntry, entry.id).aasm_state == "requested"
    end
  end

  describe "POST /admin/dnp_entries/:dnp_entry_id/transition (create) failure paths" do
    setup [:register_and_log_in_moderator]

    # NOTE: :load_resource assigns a nil dnp_entry for an unknown id on :create
    # (no not-found handler for the create action), so the controller crashes
    # with FunctionClauseError in transition_dnp_entry/3 (which requires a
    # %DnpEntry{}) instead of redirecting.
    test "raises for an unknown entry id", %{conn: conn} do
      assert_raise FunctionClauseError, fn ->
        post(conn, ~p"/admin/dnp_entries/#{0}/transition", state: "claimed")
      end
    end

    # NOTE: a non-integer entry id raises Ecto.Query.CastError (a 500).
    test "raises on a non-integer entry id", %{conn: conn} do
      assert_raise Ecto.Query.CastError, fn ->
        post(conn, ~p"/admin/dnp_entries/not-an-integer/transition", state: "claimed")
      end
    end

    # NOTE: a missing state param does not match the create/2 clause and
    # raises Phoenix.ActionClauseError (a 500).
    test "raises when the state param is missing", %{conn: conn} do
      user = confirmed_user_fixture()
      tag = tag_fixture(name: "artist:transition-nostate")
      entry = dnp_entry_fixture(user, tag)

      assert_raise Phoenix.ActionClauseError, fn ->
        post(conn, ~p"/admin/dnp_entries/#{entry}/transition")
      end
    end
  end
end
