defmodule PhilomenaWeb.Filter.SpoilerControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.FiltersFixtures
  import Philomena.TagsFixtures

  alias Philomena.Filters
  alias Philomena.Repo
  alias Philomena.Users

  # Identical shape to Filter.HideController, toggling spoilered_tag_ids
  # instead of hidden_tag_ids.

  test "anonymous POST redirects to the login page", %{conn: conn} do
    conn = post(conn, ~p"/filters/spoiler?tag=dummy-slug")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "anonymous DELETE redirects to the login page", %{conn: conn} do
    conn = delete(conn, ~p"/filters/spoiler?tag=dummy-slug")
    PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
  end

  test "banned users are redirected back with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn = post(conn, ~p"/filters/spoiler?tag=dummy-slug")

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
  end

  test "POST with the default system filter current responds 403 with an empty body",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    tag = tag_fixture()

    path = ~p"/filters/spoiler?#{[tag: tag.slug]}"
    conn = post(conn, path)

    assert response(conn, 403) == ""
  end

  test "POST spoilers the tag on the user's own current filter", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    filter = filter_fixture(user)
    {:ok, _} = Users.update_filter(user, filter)
    tag = tag_fixture()

    path = ~p"/filters/spoiler?#{[tag: tag.slug]}"
    conn = post(conn, path)

    assert response(conn, 200) == ""
    assert Repo.reload!(filter).spoilered_tag_ids == [tag.id]
  end

  test "DELETE unspoilers the tag on the user's own current filter", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    filter = filter_fixture(user)
    {:ok, _} = Users.update_filter(user, filter)
    tag = tag_fixture()
    {:ok, _} = Filters.spoiler_tag(filter, tag)

    path = ~p"/filters/spoiler?#{[tag: tag.slug]}"
    conn = delete(conn, path)

    assert response(conn, 200) == ""
    assert Repo.reload!(filter).spoilered_tag_ids == []
  end

  test "POST for an unknown tag crashes with BadMapError", %{conn: conn} do
    # NOTE: plain load_resource only runs the not_found_handler for :show
    # actions, so the nil tag reaches Filters.spoiler_tag/2, which crashes
    # on tag.id. (KNOWN-ODDITIES.md)
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    {:ok, _} = Users.update_filter(user, filter_fixture(user))

    assert_raise BadMapError, fn ->
      post(conn, ~p"/filters/spoiler?tag=unknown-slug")
    end
  end
end
