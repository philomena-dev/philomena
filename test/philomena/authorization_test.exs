defmodule Philomena.AuthorizationTest do
  @moduledoc """
  Context-level authorization matrix for `Philomena.Authorization.authorize/3`,
  the single wrapper contexts use to turn a `Canada.Can.can?/3` boolean into the
  `:ok | {:error, :unauthorized}` result shape.

  The permission rules themselves live in `Philomena.Users.Ability`
  (`lib/philomena/users/ability.ex`); these tests pin only that `authorize/3`
  maps them onto the two result shapes correctly across the actor matrix
  (anonymous `nil` / user / moderator / admin), for a few representative
  action/subject pairs.
  """

  use Philomena.DataCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Authorization
  alias Philomena.Images.Image
  alias Philomena.Tags.Tag

  setup do
    %{
      user: confirmed_user_fixture(),
      moderator: moderator_user_fixture(),
      admin: admin_user_fixture()
    }
  end

  describe "authorize/3 with a staff-only action (:edit on a Tag)" do
    # ability.ex: moderators and admins may :edit a %Tag{}; regular and
    # anonymous users may not.
    test "allows an admin", %{admin: admin} do
      assert Authorization.authorize(admin, :edit, %Tag{}) == :ok
    end

    test "allows a moderator", %{moderator: moderator} do
      assert Authorization.authorize(moderator, :edit, %Tag{}) == :ok
    end

    test "denies a regular user", %{user: user} do
      assert Authorization.authorize(user, :edit, %Tag{}) == {:error, :unauthorized}
    end

    test "denies an anonymous visitor (nil actor)" do
      assert Authorization.authorize(nil, :edit, %Tag{}) == {:error, :unauthorized}
    end
  end

  describe "authorize/3 with an admin-only action (:destroy on an Image)" do
    # ability.ex: admins can do anything; a normal moderator is *explicitly*
    # denied :destroy on an %Image{} (hard-deletion is gated behind a
    # per-resource role_map grant a plain moderator lacks).
    test "allows an admin", %{admin: admin} do
      assert Authorization.authorize(admin, :destroy, %Image{}) == :ok
    end

    test "denies a plain moderator", %{moderator: moderator} do
      assert Authorization.authorize(moderator, :destroy, %Image{}) == {:error, :unauthorized}
    end

    test "denies a regular user", %{user: user} do
      assert Authorization.authorize(user, :destroy, %Image{}) == {:error, :unauthorized}
    end

    test "denies an anonymous visitor (nil actor)" do
      assert Authorization.authorize(nil, :destroy, %Image{}) == {:error, :unauthorized}
    end
  end

  describe "authorize/3 with a universally allowed action (:show on a visible Image)" do
    # ability.ex: everyone, including anonymous visitors, may :show a
    # non-hidden %Image{}.
    setup do
      %{image: %Image{hidden_from_users: false}}
    end

    test "allows an admin", %{admin: admin, image: image} do
      assert Authorization.authorize(admin, :show, image) == :ok
    end

    test "allows a moderator", %{moderator: moderator, image: image} do
      assert Authorization.authorize(moderator, :show, image) == :ok
    end

    test "allows a regular user", %{user: user, image: image} do
      assert Authorization.authorize(user, :show, image) == :ok
    end

    test "allows an anonymous visitor (nil actor)", %{image: image} do
      assert Authorization.authorize(nil, :show, image) == :ok
    end
  end
end
