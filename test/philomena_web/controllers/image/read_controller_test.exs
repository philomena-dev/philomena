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

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/images/1/read"

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

  test "POST for an unknown image redirects with the not-found flash", %{conn: conn} do
    # NOTE: load_resource now uses required: true, so Canary runs its not-found
    # handler on :create - an unknown image redirects instead of passing nil
    # into clear_image_notification/2.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/images/999999999/read")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
  end
end
