defmodule PhilomenaWeb.Channel.SubscriptionControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ChannelsFixtures

  alias Philomena.Channels
  alias Philomena.Repo

  defp subscription_target(user) do
    channel = channel_fixture()

    %{
      path: ~p"/channels/#{channel}/subscription",
      subscribe!: fn -> {:ok, _} = Channels.create_subscription(channel, user) end,
      subscribed?: fn ->
        Repo.exists?(
          from s in Channels.Subscription,
            where: s.channel_id == ^channel.id and s.user_id == ^user.id
        )
      end
    }
  end

  subscription_toggle_tests()

  test "POST for an unknown channel redirects to / with the authorization flash",
       %{conn: conn} do
    # Canary sends the nil resource down the unauthorized path
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/channels/999999999/subscription")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "a non-integer channel id raises Ecto.Query.CastError", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    assert_raise Ecto.Query.CastError, ~r/cannot be cast to type :id/, fn ->
      post(conn, ~p"/channels/not-a-number/subscription")
    end
  end
end
