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

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/galleries/1/read"

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

  test "POST for an unknown gallery redirects with the not-found flash", %{conn: conn} do
    # NOTE: load_resource now uses required: true, so Canary runs its not-found
    # handler on :create - an unknown gallery redirects instead of passing nil
    # into clear_gallery_notification/2.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/galleries/999999999/read")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
  end
end
