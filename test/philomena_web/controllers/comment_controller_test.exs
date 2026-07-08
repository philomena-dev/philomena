defmodule PhilomenaWeb.CommentControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures

  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Comments.Comment
  alias Philomena.Repo

  setup do
    SearchHelpers.clear_index!(Comment)
    :ok
  end

  describe "GET /comments" do
    test "renders recent comments for anonymous users", %{conn: conn} do
      image = image_fixture()
      _comment = comment_fixture(image, nil, %{"body" => "Test searchable comment body"})
      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/comments")
      response = html_response(conn, 200)

      assert response =~ "Comments - Derpibooru"
      assert response =~ "Test searchable comment body"
      assert response =~ ~p"/images/#{image.id}"
    end

    test "does not show hidden comments to anonymous users", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil, %{"body" => "Test hidden comment body"})

      comment
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/comments")
      response = html_response(conn, 200)

      refute response =~ "Test hidden comment body"
    end

    test "does not show comments on hidden images to anonymous users", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)
      _comment = comment_fixture(image, nil, %{"body" => "Test orphaned comment body"})
      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/comments")
      response = html_response(conn, 200)

      refute response =~ "Test orphaned comment body"
    end

    test "filters comments with the cq parameter", %{conn: conn} do
      image = image_fixture()
      _matching = comment_fixture(image, nil, %{"body" => "Test grapefruit comment"})
      _other = comment_fixture(image, nil, %{"body" => "Test kumquat comment"})
      SearchHelpers.reindex_all!(Comment)

      conn = get(conn, ~p"/comments?cq=grapefruit")
      response = html_response(conn, 200)

      assert response =~ "Test grapefruit comment"
      refute response =~ "Test kumquat comment"
    end

    test "renders an error for an invalid cq query", %{conn: conn} do
      conn = get(conn, ~p"/comments?cq=created_at.gte:not-a-date")
      response = html_response(conn, 200)

      assert response =~ "Comments - Derpibooru"
    end
  end
end
