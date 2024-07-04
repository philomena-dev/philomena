defmodule Philomena.Comments.SubscriptionTest do
  use Philomena.DataCase

  alias Philomena.{Images, Comments}
  alias Philomena.{AttributionFixtures, ImagesFixtures, UsersFixtures}

  @params %{"body" => "hello world", "anonymous" => false}

  describe "create_comment/3" do
    setup do
      image = ImagesFixtures.image_fixture()
      user = UsersFixtures.user_fixture()
      %{image: image, user: user}
    end

    test "succeeds when user is nil", %{image: image} do
      attribution = AttributionFixtures.attribution_fixture()
      assert {:ok, _comment} = Comments.create_comment(image, attribution, @params)
    end

    test "succeeds and subscribes the user by default", %{image: image, user: user} do
      attribution = AttributionFixtures.attribution_fixture(user)
      assert {:ok, _comment} = Comments.create_comment(image, attribution, @params)
      assert Images.subscribed?(image, user)
    end

    test "succeeds and does not subscribe the user when requested", %{image: image, user: user} do
      user = %{user | watch_on_reply: false}
      attribution = AttributionFixtures.attribution_fixture(user)
      assert {:ok, _comment} = Comments.create_comment(image, attribution, @params)
      refute Images.subscribed?(image, user)
    end
  end
end
