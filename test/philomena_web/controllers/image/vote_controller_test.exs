defmodule PhilomenaWeb.Image.VoteControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ImagesFixtures

  alias Philomena.ImageVotes
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.Repo

  defp interaction_path(image_id), do: ~p"/images/#{image_id}/vote"

  image_interaction_guard_tests([:post, :delete])

  defp vote(image, user) do
    Repo.one(from v in ImageVote, where: v.image_id == ^image.id and v.user_id == ^user.id)
  end

  defp upvote!(image, user) do
    {:ok, _} = Repo.transaction(ImageVotes.create_vote_transaction(image, user, true))
  end

  describe "POST /images/:image_id/vote" do
    setup :register_and_log_in_user

    test "with a JSON `up: true` body records an upvote and returns interaction data",
         %{conn: conn, user: user} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/vote", %{"up" => true})

      assert json_response(conn, 200) == %{
               "score" => 1,
               "faves" => 0,
               "upvotes" => 1,
               "downvotes" => 0
             }

      assert %ImageVote{up: true} = vote(image, user)
    end

    test "with a JSON `up: false` body records a downvote", %{conn: conn, user: user} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/vote", %{"up" => false})

      assert json_response(conn, 200) == %{
               "score" => -1,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 1
             }

      assert %ImageVote{up: false} = vote(image, user)
    end

    test "a form-encoded up=true body records a downvote", %{conn: conn, user: user} do
      # NOTE: the controller compares `params["up"] == true` against a
      # boolean, so the string "true" from a form-encoded body counts as a
      # downvote. Only the JSON fetch client in assets/js sends a real
      # boolean. (KNOWN-ODDITIES.md)
      image = image_fixture()

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(~p"/images/#{image}/vote", "up=true")

      assert json_response(conn, 200) == %{
               "score" => -1,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 1
             }

      assert %ImageVote{up: false} = vote(image, user)
    end

    test "revoting replaces the existing vote", %{conn: conn, user: user} do
      image = image_fixture()
      upvote!(image, user)

      conn = post(conn, ~p"/images/#{image}/vote", %{"up" => false})

      assert json_response(conn, 200) == %{
               "score" => -1,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 1
             }

      assert %ImageVote{up: false} = vote(image, user)
    end
  end

  describe "DELETE /images/:image_id/vote" do
    setup :register_and_log_in_user

    test "removes the user's vote and returns interaction data", %{conn: conn, user: user} do
      image = image_fixture()
      upvote!(image, user)

      conn = delete(conn, ~p"/images/#{image}/vote")

      assert json_response(conn, 200) == %{
               "score" => 0,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 0
             }

      refute vote(image, user)
    end

    test "with no existing vote still returns 200 interaction data", %{conn: conn} do
      image = image_fixture()

      conn = delete(conn, ~p"/images/#{image}/vote")

      assert json_response(conn, 200) == %{
               "score" => 0,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 0
             }
    end
  end
end
