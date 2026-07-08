defmodule PhilomenaWeb.Image.DescriptionLockControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  # NOTE: "locking the description" is stored inverted on the
  # `description_editing_allowed` column; there is no `description_locked` field.
  defp description_editable?(image), do: Repo.reload!(image).description_editing_allowed

  describe "POST /images/:image_id/description_lock" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/description_lock")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert description_editable?(image)
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/description_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert description_editable?(image)
    end

    test "as a moderator locks the description", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/description_lock")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully locked description."
      refute description_editable?(image)
    end

    test "as an admin locks the description", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/description_lock")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully locked description."
      refute description_editable?(image)
    end

    test "for an unknown image_id redirects with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/999999999/description_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the image_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer image_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        post(conn, ~p"/images/not-a-number/description_lock")
      end
    end
  end

  describe "DELETE /images/:image_id/description_lock" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture(description_editing_allowed: false)

      conn = delete(conn, ~p"/images/#{image}/description_lock")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute description_editable?(image)
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(description_editing_allowed: false)

      conn = delete(conn, ~p"/images/#{image}/description_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute description_editable?(image)
    end

    test "as a moderator unlocks the description", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(description_editing_allowed: false)

      conn = delete(conn, ~p"/images/#{image}/description_lock")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully unlocked description."
      assert description_editable?(image)
    end

    test "as an admin unlocks the description", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture(description_editing_allowed: false)

      conn = delete(conn, ~p"/images/#{image}/description_lock")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully unlocked description."
      assert description_editable?(image)
    end

    test "for an unknown image_id redirects with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/999999999/description_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the image_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer image_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        delete(conn, ~p"/images/not-a-number/description_lock")
      end
    end
  end
end
