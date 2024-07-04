defmodule Philomena.Topics.SubscriptionTest do
  use Philomena.DataCase

  alias Philomena.Topics
  alias Philomena.{AttributionFixtures, ForumsFixtures, TopicsFixtures, UsersFixtures}

  describe "create_topic/3" do
    setup do
      user = UsersFixtures.user_fixture()
      forum = ForumsFixtures.forum_fixture()
      %{user: user, forum: forum}
    end

    test "succeeds when the user is nil", %{forum: forum} do
      attribution = AttributionFixtures.attribution_fixture()

      assert {:ok, _changes} =
               Topics.create_topic(forum, attribution, TopicsFixtures.topic_attrs())
    end

    test "succeeds and subscribes the user by default", %{forum: forum, user: user} do
      attribution = AttributionFixtures.attribution_fixture(user)

      assert {:ok, %{topic: topic}} =
               Topics.create_topic(forum, attribution, TopicsFixtures.topic_attrs())

      assert Topics.subscribed?(topic, user)
    end

    test "succeeds and does not subscribe the user when requested", %{forum: forum, user: user} do
      attribution = AttributionFixtures.attribution_fixture(%{user | watch_on_new_topic: false})

      assert {:ok, %{topic: topic}} =
               Topics.create_topic(forum, attribution, TopicsFixtures.topic_attrs())

      refute Topics.subscribed?(topic, user)
    end
  end

  describe "create_subscription/2, delete_subscription/2" do
    test "allows subscription and unsubscription" do
      user = UsersFixtures.user_fixture()
      topic = TopicsFixtures.topic_fixture()

      assert {:ok, _} = Topics.create_subscription(topic, user)
      assert {:ok, _} = Topics.delete_subscription(topic, user)
    end
  end
end
