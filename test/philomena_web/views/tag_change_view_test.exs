defmodule PhilomenaWeb.TagChangeViewTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  alias Philomena.Images.Image
  alias Philomena.TagChanges.TagChange
  alias Philomena.Users.User
  alias PhilomenaWeb.TagChangeView

  describe "reverts_tag_changes?/1" do
    test "is unavailable to anonymous and regular viewers", %{conn: conn} do
      refute TagChangeView.reverts_tag_changes?(viewer_conn(conn, nil))
      refute TagChangeView.reverts_tag_changes?(viewer_conn(conn, confirmed_user_fixture()))
    end

    test "is available to moderators and admins", %{conn: conn} do
      assert TagChangeView.reverts_tag_changes?(viewer_conn(conn, moderator_user_fixture()))
      assert TagChangeView.reverts_tag_changes?(viewer_conn(conn, admin_user_fixture()))
    end
  end

  describe "user_block_class/1" do
    test "colors the changes of a staff member who shows their role" do
      change = fn user, anonymous ->
        %TagChange{
          user: user,
          user_id: user && 1,
          image: %Image{user_id: 1, anonymous: anonymous}
        }
      end

      moderator = %User{role: "moderator", hide_default_role: false}

      assert TagChangeView.user_block_class(change.(moderator, false)) == "card-success"
      refute TagChangeView.user_block_class(change.(moderator, true))

      refute TagChangeView.user_block_class(
               change.(%{moderator | hide_default_role: true}, false)
             )

      refute TagChangeView.user_block_class(change.(%User{role: "user"}, false))
      refute TagChangeView.user_block_class(change.(nil, false))
    end
  end
end
