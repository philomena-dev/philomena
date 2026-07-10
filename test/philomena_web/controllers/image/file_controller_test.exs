defmodule PhilomenaWeb.Image.FileControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # `Images.update_file/2` drives the media pipeline synchronously
  # (analyze, persist to the stubbed S3, enqueue the dead
  # ThumbnailWorker/reindex jobs), with no spawned upload process, so this
  # file stays `async: true`.

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  describe "PATCH/PUT /images/:image_id/file" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/sessions/new"
      # Not touched - the plug pipeline halts before the action.
      assert Repo.reload!(image).processed == true
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(image).processed == true
    end

    test "as a moderator replaces the file", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated file."

      # repair_image marks the image for reprocessing.
      reloaded = Repo.reload!(image)
      assert reloaded.processed == false
      assert reloaded.thumbnails_generated == false

      # NOTE: remove_hash nulls image_orig_sha512_hash first, but the
      # subsequent analysis of the new file re-sets it, so on success the hash
      # is the new file's, not nil (contrast the no-file failure path).
      assert reloaded.image_orig_sha512_hash != nil
      assert reloaded.image_orig_sha512_hash != image.image_orig_sha512_hash
    end

    test "as an admin replaces the file", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated file."
      assert Repo.reload!(image).processed == false
    end

    # verify_not_deleted halts before replacing a hidden image.
    test "on a deleted image redirects with the deleted-image flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(hidden_from_users: true, deletion_reason: "Spam")

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Cannot replace a deleted image."
      # The hash is untouched because the action never runs.
      assert Repo.reload!(image).image_orig_sha512_hash != nil
    end

    # NOTE: update_file re-renders the "Failed to update file!" error branch on
    # a request with no file (image_changeset's validate_required(:image)
    # fails). But the action calls Images.remove_hash/1 *before* update_file, so
    # a failed replacement still nulls image_orig_sha512_hash as a side effect.
    test "without a file redirects with the failure flash but still removes the hash", %{
      conn: conn
    } do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = put(conn, ~p"/images/#{image}/file", %{"image" => %{}})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to update file!"

      reloaded = Repo.reload!(image)
      assert reloaded.image_orig_sha512_hash == nil
      # The file itself was not replaced.
      assert reloaded.processed == true
    end

    test "for an unknown image_id redirects with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        put(conn, ~p"/images/999999999/file", %{"image" => %{"image" => png_upload()}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the image_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer image_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        put(conn, ~p"/images/not-a-number/file", %{"image" => %{"image" => png_upload()}})
      end
    end
  end
end
