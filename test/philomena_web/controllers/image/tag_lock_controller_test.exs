defmodule PhilomenaWeb.Image.TagLockControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  # NOTE: "locking tags" is stored inverted on the `tag_editing_allowed`
  # column; there is no `tags_locked` field.
  defp tags_editable?(image), do: Repo.reload!(image).tag_editing_allowed

  defp locked_tag_names(image) do
    image
    |> Repo.preload(:locked_tags, force: true)
    |> Map.fetch!(:locked_tags)
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  describe "GET /images/:image_id/tag_lock" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/tag_lock")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/tag_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the lock-tags form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/tag_lock")
      response = html_response(conn, 200)

      assert response =~ "Locking image tags - Derpibooru"
      assert response =~ "Editing locked tags on image ##{image.id}"
    end

    test "renders the lock-tags form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/tag_lock")

      assert html_response(conn, 200) =~ "Editing locked tags on image ##{image.id}"
    end

    test "for an unknown image_id redirects with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/images/999999999/tag_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the image_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer image_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        get(conn, ~p"/images/not-a-number/tag_lock")
      end
    end
  end

  describe "POST /images/:image_id/tag_lock" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/tag_lock")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert tags_editable?(image)
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/tag_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert tags_editable?(image)
    end

    test "as a moderator locks tags", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/tag_lock")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully locked tags."
      refute tags_editable?(image)
    end

    test "as an admin locks tags", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/tag_lock")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully locked tags."
      refute tags_editable?(image)
    end

    test "for an unknown image_id redirects with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/images/999999999/tag_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the image_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer image_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        post(conn, ~p"/images/not-a-number/tag_lock")
      end
    end
  end

  describe "PATCH/PUT /images/:image_id/tag_lock" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/tag_lock", %{"image" => %{"tag_input" => "safe"}})

      assert redirected_to(conn) == ~p"/sessions/new"
      assert locked_tag_names(image) == []
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/tag_lock", %{"image" => %{"tag_input" => "safe"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert locked_tag_names(image) == []
    end

    test "as a moderator updates the locked tag list", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn =
        put(conn, ~p"/images/#{image}/tag_lock", %{"image" => %{"tag_input" => "safe, solo"}})

      assert redirected_to(conn) == ~p"/images/#{image}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully updated list of locked tags."

      assert locked_tag_names(image) == ["safe", "solo"]
    end

    test "as an admin updates the locked tag list", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/tag_lock", %{"image" => %{"tag_input" => "solo"}})

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully updated list of locked tags."

      assert locked_tag_names(image) == ["solo"]
    end

    # NOTE: an empty tag_input clears the locked tag list (get_or_create_tags
    # returns []); this is a success, not a validation error.
    test "an empty tag_input clears the locked tag list", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      # Lock some tags first.
      put(conn, ~p"/images/#{image}/tag_lock", %{"image" => %{"tag_input" => "safe, solo"}})
      assert locked_tag_names(image) == ["safe", "solo"]

      conn = put(conn, ~p"/images/#{image}/tag_lock", %{"image" => %{"tag_input" => ""}})

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully updated list of locked tags."

      assert locked_tag_names(image) == []
    end

    test "for an unknown image_id redirects with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        put(conn, ~p"/images/999999999/tag_lock", %{"image" => %{"tag_input" => "safe"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the image_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer image_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        put(conn, ~p"/images/not-a-number/tag_lock", %{"image" => %{"tag_input" => "safe"}})
      end
    end
  end

  describe "DELETE /images/:image_id/tag_lock" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture(tag_editing_allowed: false)

      conn = delete(conn, ~p"/images/#{image}/tag_lock")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute tags_editable?(image)
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(tag_editing_allowed: false)

      conn = delete(conn, ~p"/images/#{image}/tag_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute tags_editable?(image)
    end

    test "as a moderator unlocks tags", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(tag_editing_allowed: false)

      conn = delete(conn, ~p"/images/#{image}/tag_lock")

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully unlocked tags."
      assert tags_editable?(image)
    end

    test "as an admin unlocks tags", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture(tag_editing_allowed: false)

      conn = delete(conn, ~p"/images/#{image}/tag_lock")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully unlocked tags."
      assert tags_editable?(image)
    end

    test "for an unknown image_id redirects with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/images/999999999/tag_lock")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the image_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer image_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        delete(conn, ~p"/images/not-a-number/tag_lock")
      end
    end
  end
end
