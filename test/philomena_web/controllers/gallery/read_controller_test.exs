defmodule PhilomenaWeb.Gallery.ReadControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.GalleriesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Galleries
  alias Philomena.Notifications
  alias Philomena.Notifications.GalleryImageNotification
  alias Philomena.Repo

  defp read_target(user) do
    gallery = gallery_fixture(confirmed_user_fixture())

    %{
      path: ~p"/galleries/#{gallery}/read",
      arrange!: fn ->
        {:ok, _} = Galleries.create_subscription(gallery, user)
        {:ok, 1} = Notifications.create_gallery_image_notification(gallery)
      end,
      notification?: fn ->
        Repo.exists?(
          from n in GalleryImageNotification,
            where: n.gallery_id == ^gallery.id and n.user_id == ^user.id
        )
      end
    }
  end

  read_singleton_tests()

  test "POST for an unknown gallery crashes with FunctionClauseError", %{conn: conn} do
    # NOTE: plain load_resource only runs the not_found_handler for :show
    # actions, so the nil gallery reaches clear_gallery_notification/2 and
    # the request 500s instead of rendering not-found. (KNOWN-ODDITIES.md)
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    assert_raise FunctionClauseError, ~r/clear_gallery_notification\/2/, fn ->
      post(conn, ~p"/galleries/999999999/read")
    end
  end
end
