defmodule PhilomenaWeb.Profile.Commission.ItemControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.CommissionsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Commissions.Item
  alias Philomena.Repo

  defp valid_item_params do
    %{
      "item_type" => "Sketch",
      "description" => "Test item description",
      "base_price" => "20"
    }
  end

  describe "GET /profiles/:profile_id/commission/items/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      user = confirmed_user_fixture()
      commission_fixture(user)

      conn = get(conn, ~p"/profiles/#{user}/commission/items/new")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "renders the form for the commission's owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      commission_fixture(user)

      response = html_response(get(conn, ~p"/profiles/#{user}/commission/items/new"), 200)

      assert response =~ "New Commission Item - Derpibooru"
      assert response =~ "New Item on Listing"
    end

    test "redirects a moderator with the authorization flash", %{conn: conn} do
      # NOTE: unlike Profile.CommissionController, :ensure_correct_user here
      # has no moderator/admin bypass — items are strictly owner-only.
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      artist = confirmed_user_fixture()
      commission_fixture(artist)

      conn = get(conn, ~p"/profiles/#{artist}/commission/items/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "redirects with the not-found flash when no commission exists", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/profiles/#{user}/commission/items/new")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end

  describe "POST /profiles/:profile_id/commission/items" do
    test "creates the item and redirects to the commission", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      commission = commission_fixture(user)

      conn =
        post(conn, ~p"/profiles/#{user}/commission/items", %{
          "item" => valid_item_params()
        })

      assert redirected_to(conn) == ~p"/profiles/#{user}/commission"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Item successfully created."

      assert Repo.get_by!(Item, commission_id: commission.id).item_type == "Sketch"
    end

    test "with an unknown item type re-renders the form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      commission = commission_fixture(user)

      conn =
        post(conn, ~p"/profiles/#{user}/commission/items", %{
          "item" => %{valid_item_params() | "item_type" => "Not A Type"}
        })

      # NOTE: failure re-renders new.html without the :title assign
      assert html_response(conn, 200) =~ "New Item on Listing"
      refute Repo.get_by(Item, commission_id: commission.id)
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/profiles/some-user/commission/items", %{"item" => %{}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end
  end

  describe "GET /profiles/:profile_id/commission/items/:id/edit" do
    test "renders the form for the commission's owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      commission = commission_fixture(user)
      item = commission_item_fixture(commission)

      response =
        html_response(get(conn, ~p"/profiles/#{user}/commission/items/#{item}/edit"), 200)

      assert response =~ "Editing Commission Item - Derpibooru"
      assert response =~ "Edit Item on Listing"
    end

    test "404s for an item belonging to another commission", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      commission_fixture(user)
      other_commission = commission_fixture(confirmed_user_fixture())
      item = commission_item_fixture(other_commission)

      assert_error_sent 404, fn ->
        get(conn, ~p"/profiles/#{user}/commission/items/#{item}/edit")
      end
    end
  end

  describe "PATCH /profiles/:profile_id/commission/items/:id" do
    test "updates the item and redirects to the commission", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      commission = commission_fixture(user)
      item = commission_item_fixture(commission)

      conn =
        patch(conn, ~p"/profiles/#{user}/commission/items/#{item}", %{
          "item" => %{"description" => "Updated item description"}
        })

      assert redirected_to(conn) == ~p"/profiles/#{user}/commission"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Item successfully updated."
      assert Repo.get!(Item, item.id).description == "Updated item description"
    end

    test "with a blank description re-renders the form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      commission = commission_fixture(user)
      item = commission_item_fixture(commission)

      conn =
        patch(conn, ~p"/profiles/#{user}/commission/items/#{item}", %{
          "item" => %{"description" => ""}
        })

      assert html_response(conn, 200) =~ "Edit Item on Listing"
      assert Repo.get!(Item, item.id).description == item.description
    end
  end

  describe "DELETE /profiles/:profile_id/commission/items/:id" do
    test "deletes the item and redirects to the commission", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      commission = commission_fixture(user)
      item = commission_item_fixture(commission)

      conn = delete(conn, ~p"/profiles/#{user}/commission/items/#{item}")

      assert redirected_to(conn) == ~p"/profiles/#{user}/commission"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Item deleted successfully."
      refute Repo.get(Item, item.id)
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      commission = commission_fixture(artist)
      item = commission_item_fixture(commission)

      conn = delete(conn, ~p"/profiles/#{artist}/commission/items/#{item}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(Item, item.id)
    end
  end
end
