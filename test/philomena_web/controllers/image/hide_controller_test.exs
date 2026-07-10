defmodule PhilomenaWeb.Image.HideControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  # This is the user "hide this image" interaction, not the moderator hide
  # (which is Image.DeleteController).

  import Ecto.Query
  import Philomena.ImagesFixtures

  alias Philomena.ImageHides
  alias Philomena.ImageHides.ImageHide
  alias Philomena.Images
  alias Philomena.Repo

  defp interaction_path(image_id), do: ~p"/images/#{image_id}/hide"

  image_interaction_guard_tests([:post, :delete])

  defp hide(image, user) do
    Repo.one(from h in ImageHide, where: h.image_id == ^image.id and h.user_id == ^user.id)
  end

  defp hide!(image, user) do
    {:ok, _} = Repo.transaction(ImageHides.create_hide_transaction(image, user))
  end

  describe "POST /images/:image_id/hide" do
    setup :register_and_log_in_user

    test "records a hide and returns unchanged interaction data", %{conn: conn, user: user} do
      image = image_fixture()

      conn = post(conn, ~p"/images/#{image}/hide")

      # hides don't affect the score/fave counters in the response
      assert json_response(conn, 200) == %{
               "score" => 0,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 0
             }

      assert hide(image, user)
      assert Images.get_image!(image.id).hides_count == 1
    end

    test "when already hidden stays hidden", %{conn: conn, user: user} do
      image = image_fixture()
      hide!(image, user)

      conn = post(conn, ~p"/images/#{image}/hide")

      assert json_response(conn, 200) == %{
               "score" => 0,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 0
             }

      assert hide(image, user)
      assert Images.get_image!(image.id).hides_count == 1
    end
  end

  describe "DELETE /images/:image_id/hide" do
    setup :register_and_log_in_user

    test "removes the hide", %{conn: conn, user: user} do
      image = image_fixture()
      hide!(image, user)

      conn = delete(conn, ~p"/images/#{image}/hide")

      assert json_response(conn, 200) == %{
               "score" => 0,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 0
             }

      refute hide(image, user)
      assert Images.get_image!(image.id).hides_count == 0
    end

    test "with no existing hide still returns 200 interaction data", %{conn: conn} do
      image = image_fixture()

      conn = delete(conn, ~p"/images/#{image}/hide")

      assert json_response(conn, 200) == %{
               "score" => 0,
               "faves" => 0,
               "upvotes" => 0,
               "downvotes" => 0
             }
    end
  end
end
