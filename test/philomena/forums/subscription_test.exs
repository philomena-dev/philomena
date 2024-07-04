defmodule Philomena.Forums.SubscriptionTest do
  use Philomena.DataCase

  alias Philomena.Forums
  alias Philomena.{ForumsFixtures, UsersFixtures}

  describe "create_subscription/2, delete_subscription/2" do
    test "allows subscription and unsubscription" do
      user = UsersFixtures.user_fixture()
      forum = ForumsFixtures.forum_fixture()

      assert {:ok, _} = Forums.create_subscription(forum, user)
      assert {:ok, _} = Forums.delete_subscription(forum, user)
    end
  end
end
