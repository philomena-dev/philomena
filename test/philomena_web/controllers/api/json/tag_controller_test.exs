defmodule PhilomenaWeb.Api.Json.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.TagsFixtures

  alias Philomena.Tags

  describe "GET /api/v1/json/tags/:slug" do
    test "shows a tag by slug", %{conn: conn} do
      tag = tag_fixture(name: "safe")

      conn = get(conn, ~p"/api/v1/json/tags/#{tag}")

      assert json_response(conn, 200) == %{
               "tag" => %{
                 "id" => tag.id,
                 "name" => "safe",
                 "slug" => "safe",
                 "description" => "",
                 "short_description" => "",
                 "images" => 0,
                 "spoiler_image_uri" => nil,
                 "namespace" => nil,
                 "name_in_namespace" => "safe",
                 "category" => nil,
                 "aliased_tag" => nil,
                 "aliases" => [],
                 "implied_tags" => [],
                 "implied_by_tags" => [],
                 "dnp_entries" => []
               }
             }
    end

    test "derives namespace and category for a namespaced tag", %{conn: conn} do
      tag = tag_fixture(name: "artist:hoofbeats")

      conn = get(conn, ~p"/api/v1/json/tags/#{tag}")

      assert %{
               "tag" => %{
                 "name" => "artist:hoofbeats",
                 "slug" => "artist-colon-hoofbeats",
                 "namespace" => "artist",
                 "name_in_namespace" => "hoofbeats",
                 "category" => "origin"
               }
             } = json_response(conn, 200)
    end

    test "shows the alias target on an aliased tag and the alias on its target", %{conn: conn} do
      tag = tag_fixture(name: "pegasus pony")
      target = tag_fixture(name: "pegasus")

      {:ok, _tag} = Tags.alias_tag(tag, %{"target_tag" => target.name})

      conn1 = get(conn, ~p"/api/v1/json/tags/#{tag}")

      assert %{"tag" => %{"aliased_tag" => "pegasus", "aliases" => []}} =
               json_response(conn1, 200)

      conn2 = get(conn, ~p"/api/v1/json/tags/#{target}")

      # NOTE: slugs encode spaces as `+`, not `-`.
      assert %{"tag" => %{"aliased_tag" => nil, "aliases" => ["pegasus+pony"]}} =
               json_response(conn2, 200)
    end

    test "returns 404 for an unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/tags/nonexistent")

      # NOTE: the 404 body is empty text/plain, not a JSON error object.
      assert response(conn, 404) == ""
      assert response_content_type(conn, :text)
    end

    test "does not resolve a tag by its name when the slug differs", %{conn: conn} do
      _tag = tag_fixture(name: "artist:hoofbeats")

      # NOTE: lookup is strictly by slug; the (URL-encoded) name 404s.
      conn = get(conn, "/api/v1/json/tags/artist%3Ahoofbeats")

      assert response(conn, 404) == ""
    end
  end
end
