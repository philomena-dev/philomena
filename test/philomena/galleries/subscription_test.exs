defmodule Philomena.Galleries.SubscriptionTest do
  use Philomena.DataCase

  alias Philomena.Galleries
  alias Philomena.{GalleriesFixtures, UsersFixtures}

  describe "create_subscription/2, delete_subscription/2" do
    test "allows subscription and unsubscription" do
      user = UsersFixtures.user_fixture()
      gallery = GalleriesFixtures.gallery_fixture()

      assert {:ok, _} = Galleries.create_subscription(gallery, user)
      assert {:ok, _} = Galleries.delete_subscription(gallery, user)
    end
  end
end
