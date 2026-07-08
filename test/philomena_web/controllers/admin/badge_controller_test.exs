defmodule PhilomenaWeb.Admin.BadgeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BadgesFixtures

  alias Philomena.Badges.Badge
  alias Philomena.Repo

  describe "GET /admin/badges (index) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/badges")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/badges")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: A plain moderator (no Badge role_map entry) cannot manage badges.
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/badges")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator with the Badge role_map entry", %{conn: conn} do
      conn = log_in_role_moderator(conn, "Badge")
      conn = get(conn, ~p"/admin/badges")
      assert html_response(conn, 200) =~ "Badges"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/badges")
      assert html_response(conn, 200) =~ "Badges"
    end
  end

  describe "GET /admin/badges (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/badges")
      response = html_response(conn, 200)
      assert response =~ "Admin - Badges - Derpibooru"
      assert response =~ "Badges"
    end

    test "lists an existing badge", %{conn: conn} do
      badge = badge_fixture()
      conn = get(conn, ~p"/admin/badges")
      assert html_response(conn, 200) =~ badge.title
    end
  end

  describe "GET /admin/badges/new" do
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/new")
      assert redirected_to(conn) == "/"
    end

    test "renders the form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/new")
      response = html_response(conn, 200)
      assert response =~ "New Badge - Derpibooru"
      assert response =~ "New Badge"
    end
  end

  describe "POST /admin/badges (create)" do
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/admin/badges", %{"badge" => %{"title" => "nope", "image" => svg_upload()}})

      assert redirected_to(conn) == "/"
      refute Repo.get_by(Badge, title: "nope")
    end

    test "creates a badge as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(conn, ~p"/admin/badges", %{
          "badge" => %{"title" => "Admin Made Badge", "image" => svg_upload()}
        })

      assert redirected_to(conn) == ~p"/admin/badges"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Badge created successfully."
      assert Repo.get_by(Badge, title: "Admin Made Badge")
    end

    test "creates a badge as a Badge-role moderator", %{conn: conn} do
      conn = log_in_role_moderator(conn, "Badge")

      conn =
        post(conn, ~p"/admin/badges", %{
          "badge" => %{"title" => "Mod Made Badge", "image" => svg_upload()}
        })

      assert redirected_to(conn) == ~p"/admin/badges"
      assert Repo.get_by(Badge, title: "Mod Made Badge")
    end

    # NOTE: `Badges.create_badge/1` returns `{:error, %Ecto.Changeset{}}` on a
    # validation failure, but the controller's create/2 only matches
    # `{:error, :badge, changeset, _changes}` (a Multi-shaped tuple that the
    # context never produces). So any invalid badge submission — here, a
    # missing image — raises CaseClauseError (a 500) instead of re-rendering
    # the form. The error branch is effectively dead.
    test "500s on a validation failure (missing image)", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      assert_raise CaseClauseError, fn ->
        post(conn, ~p"/admin/badges", %{"badge" => %{"title" => "No Image Badge"}})
      end
    end
  end

  describe "GET /admin/badges/:id/edit" do
    test "rejects a plain moderator", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/edit")
      response = html_response(conn, 200)
      assert response =~ "Editing Badge - Derpibooru"
      assert response =~ "Edit Badge"
    end

    test "redirects with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{2_000_000_000}/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "crashes on a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        get(conn, ~p"/admin/badges/not-a-number/edit")
      end
    end
  end

  describe "PATCH /admin/badges/:id (update)" do
    test "rejects a plain moderator", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = patch(conn, ~p"/admin/badges/#{badge}", %{"badge" => %{"title" => "changed"}})
      assert redirected_to(conn) == "/"
    end

    test "updates the badge as an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = patch(conn, ~p"/admin/badges/#{badge}", %{"badge" => %{"title" => "Updated Title"}})

      assert redirected_to(conn) == ~p"/admin/badges"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Badge updated successfully."
      assert Repo.get(Badge, badge.id).title == "Updated Title"
    end

    # NOTE: Same dead error branch as create/2 — `update_badge/2` returns
    # `{:error, changeset}` but the controller matches
    # `{:error, :badge, changeset, _changes}`, so a blank title is a
    # CaseClauseError 500, not a re-rendered form.
    test "500s on a validation failure (blank title)", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      assert_raise CaseClauseError, fn ->
        patch(conn, ~p"/admin/badges/#{badge}", %{"badge" => %{"title" => ""}})
      end
    end
  end

  describe "PUT /admin/badges/:id (update)" do
    test "updates the badge as an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = put(conn, ~p"/admin/badges/#{badge}", %{"badge" => %{"title" => "Put Updated"}})

      assert redirected_to(conn) == ~p"/admin/badges"
      assert Repo.get(Badge, badge.id).title == "Put Updated"
    end
  end
end
