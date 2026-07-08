defmodule PhilomenaWeb.Image.Comment.DeleteControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures

  alias Philomena.Repo

  describe "POST /images/:image_id/comments/:comment_id/delete" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "keep me"})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/delete")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(comment).destroyed_content
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "keep me"})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/delete")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(comment).destroyed_content
    end

    test "as a moderator destroys the comment content", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "obliterate me"})

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/delete")

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment successfully destroyed!"

      comment = Repo.reload!(comment)
      assert comment.destroyed_content
      assert comment.body == ""
    end

    test "as an admin destroys the comment content", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image)

      conn = post(conn, ~p"/images/#{image}/comments/#{comment}/delete")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment successfully destroyed!"
      assert Repo.reload!(comment).destroyed_content
    end

    test "for an unknown comment_id redirects with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/comments/999999999/delete")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the comment_id is interpolated into the load query, so a
    # non-integer value raises Ecto.Query.CastError (a 500).
    test "for a non-integer comment_id raises CastError", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      assert_raise Ecto.Query.CastError, fn ->
        post(conn, ~p"/images/#{image}/comments/not-a-number/delete")
      end
    end
  end
end
