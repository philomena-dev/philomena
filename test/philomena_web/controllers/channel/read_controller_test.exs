defmodule PhilomenaWeb.Channel.ReadControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ChannelsFixtures

  alias Philomena.Channels
  alias Philomena.Notifications
  alias Philomena.Notifications.ChannelLiveNotification
  alias Philomena.Repo

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/channels/1/read"

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

  test "POST for an unknown channel redirects with the not-found flash", %{conn: conn} do
    # NOTE: load_resource now uses required: true, so Canary runs its not-found
    # handler on :create - an unknown channel redirects instead of passing nil
    # into clear_channel_notification/2.
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/channels/999999999/read")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
  end

  test "a non-integer channel id redirects with the not-found flash", %{conn: conn} do
    # the central IntegerId guard short-circuits a non-integer id to NotFoundPlug
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn = post(conn, ~p"/channels/not-a-number/read")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
  end
end
