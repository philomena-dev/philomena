defmodule PhilomenaWeb.Gallery.SubscriptionControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.GalleriesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Galleries
  alias Philomena.Repo

  defp subscription_target(user) do
    gallery = gallery_fixture(confirmed_user_fixture())

    %{
      path: ~p"/galleries/#{gallery}/subscription",
      subscribe!: fn -> {:ok, _} = Galleries.create_subscription(gallery, user) end,
      subscribed?: fn ->
        Repo.exists?(
          from s in Galleries.Subscription,
            where: s.gallery_id == ^gallery.id and s.user_id == ^user.id
        )
      end
    }
  end

  subscription_toggle_tests()

  test "POST for an unknown gallery redirects to / with the authorization flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/galleries/999999999/subscription")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end
end
