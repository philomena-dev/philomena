defmodule Philomena.Posts.SubscriptionTest do
  use Philomena.DataCase

  alias Philomena.{Topics, Posts}
  alias Philomena.{AttributionFixtures, TopicsFixtures, UsersFixtures}

  describe "create_post/3" do
    setup do
      topic = TopicsFixtures.topic_fixture()
      user = UsersFixtures.user_fixture()
      %{topic: topic, user: user}
    end

    test "succeeds when user is nil", %{topic: topic} do
      attribution = AttributionFixtures.attribution_fixture()
      assert {:ok, _changes} = Posts.create_post(topic, attribution, TopicsFixtures.post_attrs())
    end

    test "succeeds and subscribes the user by default", %{topic: topic, user: user} do
      attribution = AttributionFixtures.attribution_fixture(user)
      assert {:ok, _changes} = Posts.create_post(topic, attribution, TopicsFixtures.post_attrs())
      assert Topics.subscribed?(topic, user)
    end

    test "succeeds and does not subscribe the user when requested", %{topic: topic, user: user} do
      user = %{user | watch_on_reply: false}
      attribution = AttributionFixtures.attribution_fixture(user)
      assert {:ok, _changes} = Posts.create_post(topic, attribution, TopicsFixtures.post_attrs())
      refute Topics.subscribed?(topic, user)
    end
  end
end
