defmodule PhilomenaWeb.Image.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Ecto.Query
  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures

  alias PhilomenaQuery.SearchHelpers
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags.Tag
  alias Philomena.Repo

  setup do
    # The successful update actions re-render the image's _tags.html.slime
    # partial, whose quick tag table queries the tags index
    # (TagView.lookup_quick_tags/1). Without the index the render 500s.
    SearchHelpers.clear_index!(Tag)

    # Valkey tag-change counters (rltcn:/rltcr:, 50 per 10 min) are keyed by IP
    # and are not rolled back by the SQL sandbox. The logged-in tests below
    # author tag changes from the default ConnTest IP, so the counter
    # accumulates across runs until check_limits trips (a 300 with an empty
    # body). The anonymous tests use put_unique_ip/1 and need no reset.
    reset_tag_change_limits(ip: "127.0.0.1")
    :ok
  end

  # LimitPlug keys anonymous metadata updates by remote IP in Valkey, which
  # is shared across the whole (concurrent) test run — give each anonymous
  # write its own address.
  defp put_unique_ip(conn) do
    n = System.unique_integer([:positive])
    %{conn | remote_ip: {10, rem(div(n, 65536), 256), rem(div(n, 256), 256), rem(n, 256)}}
  end

  defp tag_names(image) do
    image |> Repo.preload(:tags, force: true) |> Map.fetch!(:tags) |> Enum.map(& &1.name)
  end

  test "PATCH as a logged-in user updates the tags and renders the partial", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    conn =
      patch(conn, ~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, added test tag, other added tag"
        }
      })

    response = html_response(conn, 200)

    assert response =~ "added test tag"
    refute response =~ "Derpibooru"

    assert Enum.sort(tag_names(image)) == ["added test tag", "other added tag", "safe"]

    assert Repo.exists?(
             from tc in TagChange,
               where: tc.image_id == ^image.id and tc.user_id == ^user.id
           )
  end

  test "PUT behaves like PATCH", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    conn =
      put(conn, ~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, added test tag, other added tag"
        }
      })

    assert html_response(conn, 200) =~ "added test tag"
  end

  test "PATCH anonymously updates the tags", %{conn: conn} do
    image = image_fixture()

    conn =
      conn
      |> put_unique_ip()
      |> patch(~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, added test tag, other added tag"
        }
      })

    assert html_response(conn, 200) =~ "added test tag"

    assert Repo.exists?(
             from tc in TagChange,
               where: tc.image_id == ^image.id and is_nil(tc.user_id)
           )
  end

  test "PATCH reducing the image below 3 tags renders the partial without changing tags",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    conn =
      patch(conn, ~p"/images/#{image}/tags", %{
        "image" => %{"old_tag_input" => "safe", "tag_input" => "safe, one more"}
      })

    assert html_response(conn, 200)
    assert tag_names(image) == ["safe"]
    refute Repo.exists?(from tc in TagChange, where: tc.image_id == ^image.id)
  end

  test "PATCH on an image with tag editing disabled redirects with the authorization flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture(tag_editing_allowed: false)

    conn =
      patch(conn, ~p"/images/#{image}/tags", %{
        "image" => %{"old_tag_input" => "safe", "tag_input" => "safe, a, b"}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "PATCH as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn = patch(conn, ~p"/images/999999999/tags", %{"image" => %{}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end
end
