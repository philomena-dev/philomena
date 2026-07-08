defmodule PhilomenaWeb.Api.Json.CommentControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Characterization tests: these pin the current observable behavior of the
  # endpoint (see CHARACTERIZATION-TESTS.md), they do not specify desired
  # behavior.

  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments

  describe "GET /api/v1/json/comments/:id" do
    test "shows a signed comment", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "A signed comment"})

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      %{"comment" => body} = json_response(conn, 200)

      # NOTE: the avatar of a user without an uploaded avatar is a generated
      # SVG data URI, so it is asserted by shape only.
      {avatar, body} = Map.pop(body, "avatar")
      assert is_binary(avatar)

      assert body == %{
               "id" => comment.id,
               "image_id" => image.id,
               "user_id" => user.id,
               "author" => user.name,
               "body" => "A signed comment",
               "created_at" => DateTime.to_iso8601(comment.created_at),
               "updated_at" => DateTime.to_iso8601(comment.updated_at),
               "edited_at" => nil,
               "edit_reason" => nil
             }
    end

    test "hides the author of an anonymous comment", %{conn: conn} do
      user = confirmed_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Anon comment", "anonymous" => "true"})

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      assert %{"comment" => %{"user_id" => nil, "author" => author}} = json_response(conn, 200)
      assert author =~ ~r/\ABackground Pony #[0-9A-F]{4}\z/
    end

    test "attributes a fully anonymous comment to Background Pony", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil)

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      assert %{"comment" => %{"user_id" => nil, "author" => author}} = json_response(conn, 200)
      assert author =~ ~r/\ABackground Pony #[0-9A-F]{4}\z/
    end

    test "nulls out the body of a hidden comment but stays 200", %{conn: conn} do
      user = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      image = image_fixture()
      comment = comment_fixture(image, user, %{"body" => "Rule-breaking comment"})

      {:ok, _} = Comments.hide_comment(comment, %{"deletion_reason" => "spam"}, moderator)

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      assert %{
               "comment" => %{
                 "body" => nil,
                 "edited_at" => nil,
                 "edit_reason" => nil,
                 "author" => author
               }
             } = json_response(conn, 200)

      assert author == user.name
    end

    test "returns 404 for a destroyed comment", %{conn: conn} do
      image = image_fixture()
      comment = comment_fixture(image, nil)

      {:ok, _} = Comments.destroy_comment(comment)

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      # NOTE: the 404 body is empty text/plain, not a JSON error object.
      assert response(conn, 404) == ""
      assert response_content_type(conn, :text)
    end

    test "returns 403 for a comment on a hidden image", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)
      comment = comment_fixture(image, nil)

      conn = get(conn, ~p"/api/v1/json/comments/#{comment.id}")

      assert response(conn, 403) == ""
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/comments/#{0}")

      assert response(conn, 404) == ""
    end

    test "raises for a non-integer id", %{conn: conn} do
      # NOTE: the id is interpolated into the query without casting, so a
      # non-integer id becomes a 500 rather than a 404.
      assert_raise Ecto.Query.CastError, fn ->
        get(conn, ~p"/api/v1/json/comments/not-a-number")
      end
    end
  end
end
