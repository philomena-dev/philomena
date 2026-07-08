defmodule PhilomenaWeb.Channel.ReadControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ChannelsFixtures

  alias Philomena.Channels
  alias Philomena.Notifications
  alias Philomena.Notifications.ChannelLiveNotification
  alias Philomena.Repo

  defp read_target(user) do
    channel = channel_fixture()

    %{
      path: ~p"/channels/#{channel}/read",
      arrange!: fn ->
        {:ok, _} = Channels.create_subscription(channel, user)
        {:ok, 1} = Notifications.create_channel_live_notification(channel)
      end,
      notification?: fn ->
        Repo.exists?(
          from n in ChannelLiveNotification,
            where: n.channel_id == ^channel.id and n.user_id == ^user.id
        )
      end
    }
  end

  read_singleton_tests()

  test "POST for an unknown channel crashes with FunctionClauseError", %{conn: conn} do
    # NOTE: plain load_resource only runs the not_found_handler for :show
    # actions, so the nil channel reaches clear_channel_notification/2 and
    # the request 500s instead of rendering not-found. (KNOWN-ODDITIES.md)
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    assert_raise FunctionClauseError, ~r/clear_channel_notification\/2/, fn ->
      post(conn, ~p"/channels/999999999/read")
    end
  end

  test "a non-integer channel id raises Ecto.Query.CastError", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    assert_raise Ecto.Query.CastError, ~r/cannot be cast to type :id/, fn ->
      post(conn, ~p"/channels/not-a-number/read")
    end
  end
end
