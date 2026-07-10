defmodule PhilomenaWeb.Image.RepairControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  describe "POST /images/:image_id/repair" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/repair")

      assert redirected_to(conn) == ~p"/sessions/new"
      # untouched: still marked processed
      assert Repo.reload!(image).processed
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/repair")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(image).processed
    end

    # repair_image flags the image for reprocessing (the actual thumbnail
    # job is enqueued to a dead queue in tests).
    test "as a moderator enqueues the repair and flags the image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/repair")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Repair job enqueued."

      image = Repo.reload!(image)
      refute image.processed
      refute image.thumbnails_generated
    end

    test "as an admin enqueues the repair", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/repair")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Repair job enqueued."
      refute Repo.reload!(image).processed
    end

    test "for an unknown image_id redirects with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/999999999/repair")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the image_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer image_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        post(conn, ~p"/images/not-a-number/repair")
      end
    end
  end
end
