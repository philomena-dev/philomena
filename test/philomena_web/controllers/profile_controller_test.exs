defmodule PhilomenaWeb.ProfileControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Comments.Comment
  alias Philomena.Images.Image
  alias Philomena.Posts.Post
  alias Philomena.Repo

  setup do
    SearchHelpers.recreate_index!(Image)
    SearchHelpers.recreate_index!(Comment)
    SearchHelpers.recreate_index!(Post)
    :ok
  end

  describe "GET /profiles/:slug" do
    test "renders a profile for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture(%{name: "Test Profile User"})

      user
      |> Ecto.Changeset.change(description: "All *about* this test user.")
      |> Repo.update!()

      conn = get(conn, ~p"/profiles/#{user}")
      response = html_response(conn, 200)

      assert response =~ "Test Profile User&#39;s profile - Derpibooru"
      assert response =~ "All <em>about</em> this test user."
    end

    test "renders a profile for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      user = confirmed_user_fixture(%{name: "Test Profile User"})

      conn = get(conn, ~p"/profiles/#{user}")
      response = html_response(conn, 200)

      assert response =~ "Test Profile User&#39;s profile - Derpibooru"
    end

    test "shows recent uploads, comments, and posts", %{conn: conn} do
      user = confirmed_user_fixture(%{name: "Test Active User"})

      image = image_fixture(user_id: user.id)
      _comment = comment_fixture(image, user, %{"body" => "Test profile comment body"})

      topic = topic_fixture(forum_fixture(), user)
      _post = post_fixture(topic, user, %{"body" => "Test profile post body"})

      SearchHelpers.reindex_all!(Image)
      SearchHelpers.reindex_all!(Comment)
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/profiles/#{user}")
      response = html_response(conn, 200)

      assert response =~ ~p"/images/#{image.id}"
      assert response =~ "Test profile comment body"
      assert response =~ topic.title
    end

    test "redirects to / for an unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/profiles/nonexistent-user")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end
  end
end
