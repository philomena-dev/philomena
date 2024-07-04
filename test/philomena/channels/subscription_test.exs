defmodule Philomena.Channels.SubscriptionTest do
  use Philomena.DataCase

  alias Philomena.Channels
  alias Philomena.{ChannelsFixtures, UsersFixtures}

  describe "subscriptions/2" do
    setup do
      user = UsersFixtures.user_fixture()
      channel = ChannelsFixtures.channel_fixture()

      %{user: user, channel: channel}
    end

    test "returns no subscriptions with nil user", %{channel: channel} do
      assert %{} == Channels.subscriptions([channel], nil)
    end

    test "returns no subscriptions with non-subscribed user", %{channel: channel, user: user} do
      assert %{} == Channels.subscriptions([channel], user)
    end

    test "returns subscription with subscribed user", %{channel: channel, user: user} do
      {:ok, _} = Channels.create_subscription(channel, user)
      assert %{channel.id => true} == Channels.subscriptions([channel], user)
    end
  end

  describe "create_subscription/2, delete_subscription/2" do
    test "allows subscription and unsubscription" do
      user = UsersFixtures.user_fixture()
      channel = ChannelsFixtures.channel_fixture()

      assert {:ok, _} = Channels.create_subscription(channel, user)
      assert {:ok, _} = Channels.delete_subscription(channel, user)
    end
  end
end
