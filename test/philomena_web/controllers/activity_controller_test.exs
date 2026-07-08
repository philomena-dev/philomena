defmodule PhilomenaWeb.ActivityControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Comments.Comment
  alias Philomena.Images
  alias Philomena.Images.Image

  setup do
    SearchHelpers.clear_index!(Image)
    SearchHelpers.clear_index!(Comment)
    :ok
  end

  describe "GET /" do
    test "renders the homepage on an empty site for anonymous users", %{conn: conn} do
      conn = get(conn, ~p"/")

      assert html_response(conn, 200) =~ "Homepage - Derpibooru"
    end

    test "shows recent images, comments, and forum topics", %{conn: conn} do
      image = image_fixture(created_at: hours_ago(1))
      comment = comment_fixture(image, nil, %{"body" => "Test activity comment body"})
      topic = topic_fixture(forum_fixture())

      SearchHelpers.reindex_all!(Image)
      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ ~p"/images/#{image.id}"
      # The comment strip renders only a link to the comment, not its body.
      assert response =~ "/#{image.id}#comment_#{comment.id}"
      assert response =~ topic.title
    end

    test "shows the featured image", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture(created_at: hours_ago(1))
      {:ok, _feature} = Images.feature_image(user, image)

      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "Featured Image"
    end

    test "renders the homepage for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      image = image_fixture(created_at: hours_ago(1))
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "Homepage - Derpibooru"
      assert response =~ ~p"/images/#{image.id}"
    end
  end

  describe "GET /activity" do
    test "renders the same homepage", %{conn: conn} do
      conn = get(conn, ~p"/activity")

      assert html_response(conn, 200) =~ "Homepage - Derpibooru"
    end
  end

  defp hours_ago(hours) do
    DateTime.utc_now()
    |> DateTime.add(-hours * 3600, :second)
    |> DateTime.truncate(:second)
  end
end
