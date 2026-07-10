defmodule PhilomenaWeb.Image.Comment.HistoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments

  describe "GET /images/:image_id/comments/:comment_id/history" do
    test "renders the edit history for anonymous users", %{conn: conn} do
      image = image_fixture()
      author = confirmed_user_fixture()
      comment = comment_fixture(image, author, %{"body" => "Original comment body"})

      {:ok, _} =
        Comments.update_comment(comment, author, %{
          "body" => "Original comment body plus an edit",
          "edit_reason" => "typo fix"
        })

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}/history")
      response = html_response(conn, 200)

      assert response =~ "Comment History for comment #{comment.id} on image #{image.id}"
      assert response =~ "Viewing last 25 versions of comment by"
      assert response =~ author.name
      # The version body is rendered as a character-level diff against the
      # current body, so only the shared prefix survives contiguously; the
      # edit's addition is wrapped in an <ins> tag.
      assert response =~ "Original comment body"
      assert response =~ "<ins class=\"differ\">"
    end

    test "renders an empty history for a never-edited comment", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image)

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}/history")
      response = html_response(conn, 200)

      assert response =~ "Comment History for comment #{comment.id} on image #{image.id}"
    end

    test "redirects to / for an unknown comment", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/comments/999999999/history")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / for an unknown image", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999/comments/1/history")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end
  end
end
