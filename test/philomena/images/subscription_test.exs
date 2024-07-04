defmodule Philomena.Images.SubscriptionTest do
  use Philomena.DataCase

  alias Philomena.Images
  alias Philomena.{AttributionFixtures, ImagesFixtures, UsersFixtures}

  describe "create_image/2" do
    setup do
      %{user: UsersFixtures.user_fixture()}
    end

    test "succeeds when user is nil" do
      attribution = AttributionFixtures.attribution_fixture()
      assert {:ok, _changes} = Images.create_image(attribution, ImagesFixtures.upload_attrs())
    end

    test "succeeds and subscribes the user by default", %{user: user} do
      attribution = AttributionFixtures.attribution_fixture(user)

      assert {:ok, %{image: image}} =
               Images.create_image(attribution, ImagesFixtures.upload_attrs())

      assert Images.subscribed?(image, user)
    end

    test "succeeds and does not subscribe the user when requested", %{user: user} do
      attribution = AttributionFixtures.attribution_fixture(%{user | watch_on_upload: false})

      assert {:ok, %{image: image}} =
               Images.create_image(attribution, ImagesFixtures.upload_attrs())

      refute Images.subscribed?(image, user)
    end
  end

  describe "create_subscription/2, delete_subscription/2" do
    test "allows subscription and unsubscription" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture()

      assert {:ok, _} = Images.create_subscription(image, user)
      assert {:ok, _} = Images.delete_subscription(image, user)
    end
  end
end
