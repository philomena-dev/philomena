defmodule PhilomenaWeb.Image.ReadControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images
  alias Philomena.Notifications
  alias Philomena.Notifications.ImageCommentNotification
  alias Philomena.Repo

  defp read_target(user) do
    image = image_fixture()

    %{
      path: ~p"/images/#{image}/read",
      arrange!: fn ->
        {:ok, _} = Images.create_subscription(image, user)
        author = confirmed_user_fixture()
        comment = comment_fixture(image, author)
        {:ok, 1} = Notifications.create_image_comment_notification(author, image, comment)
      end,
      notification?: fn ->
        Repo.exists?(
          from n in ImageCommentNotification,
            where: n.image_id == ^image.id and n.user_id == ^user.id
        )
      end
    }
  end

  read_singleton_tests()

  test "POST for an unknown image crashes with FunctionClauseError", %{conn: conn} do
    # NOTE: plain load_resource only runs the not_found_handler for :show
    # actions, so the nil image reaches clear_image_notification/2 and the
    # request 500s instead of rendering not-found. (KNOWN-ODDITIES.md)
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    assert_raise FunctionClauseError, ~r/clear_image_notification\/2/, fn ->
      post(conn, ~p"/images/999999999/read")
    end
  end
end
