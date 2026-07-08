defmodule PhilomenaWeb.Profile.SourceChangeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images

  defp source_change!(user, source) do
    image = image_fixture()

    {:ok, _} =
      Images.update_sources(image, attribution(user), %{
        "old_sources" => %{},
        "sources" => %{"0" => %{"source" => source}}
      })

    image
  end

  describe "GET /profiles/:profile_id/source_changes" do
    test "lists a user's source changes for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      source_change!(user, "https://example.com/profile-source")

      conn = get(conn, ~p"/profiles/#{user}/source_changes")
      response = html_response(conn, 200)

      assert response =~ "Source Changes for User"
      assert response =~ user.name
      assert response =~ "https://example.com/profile-source"
    end

    test "renders with no source changes", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/source_changes")

      assert html_response(conn, 200) =~ "Source Changes for User"
    end

    test "filters to removals with added=0", %{conn: conn} do
      user = confirmed_user_fixture()
      source_change!(user, "https://example.com/added-source")

      conn = get(conn, ~p"/profiles/#{user}/source_changes?#{[added: 0]}")
      response = html_response(conn, 200)

      assert response =~ "Source Changes for User"
      refute response =~ "https://example.com/added-source"
    end

    test "redirects to / for an unknown profile", %{conn: conn} do
      conn = get(conn, ~p"/profiles/nonexistent-user/source_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end
  end
end
