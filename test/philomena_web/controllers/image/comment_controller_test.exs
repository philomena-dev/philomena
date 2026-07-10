defmodule PhilomenaWeb.Image.CommentControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments.Comment
  alias Philomena.Repo

  describe "GET /images/:image_id/comments" do
    test "renders the comment list without a layout", %{conn: conn} do
      image = image_fixture()
      _comment = comment_fixture(image, nil, %{"body" => "Test listed comment body"})

      conn = get(conn, ~p"/images/#{image}/comments")
      response = html_response(conn, 200)

      assert response =~ "Test listed comment body"
      refute response =~ "Derpibooru"
    end

    test "redirects to the page containing a given comment", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image)

      conn = get(conn, ~p"/images/#{image}/comments?comment_id=#{comment.id}")

      assert redirected_to(conn) == ~p"/images/#{image}/comments?#{[page: 1]}"
    end

    test "redirects to / for an unknown image", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999/comments")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end
  end

  describe "GET /images/:image_id/comments/:id" do
    test "renders a single comment without a layout", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Test shown comment body"})

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}")
      response = html_response(conn, 200)

      assert response =~ "Test shown comment body"
      refute response =~ "Derpibooru"
    end

    test "redirects to / for a comment on a hidden image", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)
      comment = comment_fixture(image)

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "redirects to / for an unknown comment", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/comments/999999999")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end

  describe "POST /images/:image_id/comments" do
    test "as a logged-in user creates the comment and redirects to its page", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/comments", %{
          "comment" => %{"body" => "A brand new comment"}
        })

      comment = Repo.one!(from c in Comment, where: c.image_id == ^image.id)

      assert redirected_to(conn) == ~p"/images/#{image}/comments?#{[page: 1]}"
      assert comment.user_id == user.id
      assert comment.body == "A brand new comment"
      assert comment.approved
      assert Repo.reload!(image).comments_count == 1
    end

    test "anonymously creates the comment", %{conn: conn} do
      image = image_fixture()

      conn =
        conn
        |> put_unique_ip()
        |> post(~p"/images/#{image}/comments", %{
          "comment" => %{"body" => "An anonymous comment"}
        })

      comment = Repo.one!(from c in Comment, where: c.image_id == ^image.id)

      assert redirected_to(conn) == ~p"/images/#{image}/comments?#{[page: 1]}"
      assert comment.user_id == nil
      assert comment.body == "An anonymous comment"
    end

    test "with an empty body redirects to the image with an error flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/comments", %{"comment" => %{"body" => ""}})

      assert redirected_to(conn) == ~p"/images/#{image}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "There was an error posting your comment"

      assert Repo.aggregate(Comment, :count) == 0
    end

    test "on an image with commenting disabled redirects with the authorization flash",
         %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture(commenting_allowed: false)

      conn =
        post(conn, ~p"/images/#{image}/comments", %{
          "comment" => %{"body" => "Should not appear"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "as a banned user redirects with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})
      image = image_fixture()

      conn =
        post(conn, ~p"/images/#{image}/comments", %{
          "comment" => %{"body" => "Should not appear"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end
  end

  describe "GET /images/:image_id/comments/:id/edit" do
    test "anonymous request redirects to the login page", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image)

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}/edit")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "as the comment author renders the edit form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Editable comment body"})

      response = html_response(get(conn, ~p"/images/#{image}/comments/#{comment}/edit"), 200)

      assert response =~ "Editing Comment - Derpibooru"
      assert response =~ "Editable comment body"
    end

    test "as another user redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, confirmed_user_fixture())

      conn = get(conn, ~p"/images/#{image}/comments/#{comment}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "PATCH /images/:image_id/comments/:id" do
    test "as the comment author updates the body and redirects to the image", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Original comment body"})

      conn =
        patch(conn, ~p"/images/#{image}/comments/#{comment}", %{
          "comment" => %{"body" => "Original comment body plus an edit"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Comment updated successfully."
      assert Repo.reload!(comment).body == "Original comment body plus an edit"
    end

    test "with an empty body re-renders the edit form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Original comment body"})

      conn =
        patch(conn, ~p"/images/#{image}/comments/#{comment}", %{
          "comment" => %{"body" => ""}
        })

      # the error branch re-renders edit.html without the :title assign,
      # so the page title is bare "Derpibooru"; pin the form's error box
      assert html_response(conn, 200) =~
               "Oops, something went wrong! Please check the errors below."

      assert Repo.reload!(comment).body == "Original comment body"
    end

    test "as another user redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, confirmed_user_fixture(), %{"body" => "Untouchable"})

      conn =
        patch(conn, ~p"/images/#{image}/comments/#{comment}", %{
          "comment" => %{"body" => "Vandalism"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(comment).body == "Untouchable"
    end

    test "PUT behaves like PATCH", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Original comment body"})

      conn =
        put(conn, ~p"/images/#{image}/comments/#{comment}", %{
          "comment" => %{"body" => "Original comment body plus an edit"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}" <> "#comment_#{comment.id}"
      assert Repo.reload!(comment).body == "Original comment body plus an edit"
    end

    test "for an unknown comment redirects to / with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn =
        patch(conn, ~p"/images/#{image}/comments/999999999", %{
          "comment" => %{"body" => "Anything"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end
end
