defmodule PhilomenaWeb.Image.UploaderControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo

  defp uploader_id(image), do: Repo.reload!(image).user_id

  describe "PATCH/PUT /images/:image_id/uploader" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn =
        put(conn, ~p"/images/#{image}/uploader", %{"image" => %{"username" => "somebody"}})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    # NOTE: verify_authorized checks `:show, :ip_address`, which a regular
    # user lacks, so they get the authorization redirect.
    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn =
        put(conn, ~p"/images/#{image}/uploader", %{"image" => %{"username" => "somebody"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "as a moderator reassigns the uploader and renders the partial", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      new_uploader = user_fixture()
      image = image_fixture()

      conn =
        put(conn, ~p"/images/#{image}/uploader", %{
          "image" => %{"username" => new_uploader.name}
        })

      assert html_response(conn, 200) =~ new_uploader.name
      assert uploader_id(image) == new_uploader.id
    end

    test "as an admin reassigns the uploader", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      new_uploader = user_fixture()
      image = image_fixture()

      conn =
        put(conn, ~p"/images/#{image}/uploader", %{
          "image" => %{"username" => new_uploader.name}
        })

      assert response(conn, 200)
      assert uploader_id(image) == new_uploader.id
    end

    # NOTE: an empty username sets the uploader to nil (anonymizes it), the
    # documented "Empty for anonymous" behavior in the form.
    test "an empty username clears the uploader", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      original = user_fixture()
      image = image_fixture(user_id: original.id)

      conn = put(conn, ~p"/images/#{image}/uploader", %{"image" => %{"username" => ""}})

      assert response(conn, 200)
      assert uploader_id(image) == nil
    end

    # NOTE: an unknown username hits Repo.get_by!(User, name: ...) in the
    # changeset and raises Ecto.NoResultsError (a 500), not a validation error.
    test "an unknown username raises NoResultsError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        put(conn, ~p"/images/#{image}/uploader", %{
          "image" => %{"username" => "no-such-user-#{System.unique_integer([:positive])}"}
        })
      end
    end

    # NOTE: unlike the load_and_authorize_resource controllers, this one loads
    # with plain load_resource, and Canary's not_found_handler runs on :update,
    # so an unknown id redirects rather than crashing.
    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        put(conn, ~p"/images/999999999/uploader", %{"image" => %{"username" => "somebody"}})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: the image_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer image_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        put(conn, ~p"/images/not-a-number/uploader", %{"image" => %{"username" => "somebody"}})
      end
    end
  end
end
