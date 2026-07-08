defmodule PhilomenaWeb.Api.Json.OembedControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Characterization tests: these pin the current observable behavior of the
  # endpoint (see CHARACTERIZATION-TESTS.md), they do not specify desired
  # behavior.

  import Philomena.ImagesFixtures

  describe "GET /api/v1/json/oembed" do
    test "renders the full oembed document for a site image URL", %{conn: conn} do
      image =
        image_fixture(
          tags: "safe, artist:labra",
          sources: ["https://example.com/art/1", "https://example.com/art/2"]
        )

      url = "https://derpibooru.org/images/#{image.id}"
      conn = get(conn, ~p"/api/v1/json/oembed?url=#{url}")

      %{year: year, month: month, day: day} = image.created_at
      body = json_response(conn, 200)

      # NOTE: tag order in derpibooru_tags is the (unordered) association
      # preload order, so it is asserted separately.
      assert Enum.sort(body["derpibooru_tags"]) == ["artist:labra", "safe"]

      assert Map.delete(body, "derpibooru_tags") == %{
               "type" => "photo",
               "version" => "1.0",
               "title" => "##{image.id} - artist:labra, safe - Derpibooru",
               "author_name" => "labra",
               "author_url" => "https://example.com/art/1",
               "provider_name" => "Derpibooru",
               "provider_url" => "http://localhost:4002",
               "cache_age" => 7200,
               "thumbnail_url" => "/img/#{year}/#{month}/#{day}/#{image.id}/full.png",
               "thumbnail_width" => 100,
               "thumbnail_height" => 100,
               "url" => "/img/view/#{year}/#{month}/#{day}/#{image.id}.png",
               "width" => 100,
               "height" => 100,
               "derpibooru_id" => image.id,
               "derpibooru_score" => 0,
               "derpibooru_comments" => 0
             }
    end

    test "extracts the image id from CDN file URLs", %{conn: conn} do
      image = image_fixture()
      %{year: year, month: month, day: day} = image.created_at

      for url <- [
            "https://derpicdn.net/img/#{year}/#{month}/#{day}/#{image.id}/full.png",
            "https://derpicdn.net/img/view/#{year}/#{month}/#{day}/#{image.id}.png",
            "https://derpicdn.net/img/view/#{year}/#{month}/#{day}/#{image.id}__safe.png"
          ] do
        conn = get(conn, ~p"/api/v1/json/oembed?url=#{url}")

        assert %{"derpibooru_id" => id} = json_response(conn, 200)
        assert id == image.id
      end
    end

    test "mistakes a date component for the image id when a CDN URL has no id segment",
         %{conn: conn} do
      image = image_fixture()

      # NOTE: the CDN regex just grabs the last number followed by `/x`, `_x`
      # or `.`, so in a URL without an id segment the day component (here the
      # fixture image's id) is looked up as an image id.
      url = "https://derpicdn.net/img/2026/7/#{image.id}/full.png"
      conn = get(conn, ~p"/api/v1/json/oembed?url=#{url}")

      assert %{"derpibooru_id" => id} = json_response(conn, 200)
      assert id == image.id
    end

    test "renders empty author fields for an image without artist tags or sources",
         %{conn: conn} do
      image = image_fixture(tags: "")

      url = "https://derpibooru.org/images/#{image.id}"
      conn = get(conn, ~p"/api/v1/json/oembed?url=#{url}")

      body = json_response(conn, 200)

      # NOTE: no tags produces a double space in the title.
      assert body["title"] == "##{image.id} -  - Derpibooru"
      assert body["author_name"] == ""
      assert body["author_url"] == ""
      assert body["derpibooru_tags"] == []
    end

    test "returns 404 with a JSON error body for an unknown image id", %{conn: conn} do
      url = "https://derpibooru.org/images/1000"
      conn = get(conn, ~p"/api/v1/json/oembed?url=#{url}")

      # NOTE: unlike the other JSON API endpoints (empty text/plain 404),
      # oembed renders a JSON error object.
      assert json_response(conn, 404) == %{"error" => "Couldn't find an image"}
    end

    test "returns 404 for an image hidden from users", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)

      url = "https://derpibooru.org/images/#{image.id}"
      conn = get(conn, ~p"/api/v1/json/oembed?url=#{url}")

      assert json_response(conn, 404) == %{"error" => "Couldn't find an image"}
    end

    test "returns 404 for a URL whose path contains no number", %{conn: conn} do
      url = "https://derpibooru.org/images/abc"
      conn = get(conn, ~p"/api/v1/json/oembed?url=#{url}")

      assert json_response(conn, 404) == %{"error" => "Couldn't find an image"}
    end

    test "returns 404 when the url parameter is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/oembed")

      assert json_response(conn, 404) == %{"error" => "Couldn't find an image"}
    end

    test "crashes on a URL without a path", %{conn: conn} do
      # NOTE: URI.parse/1 yields a nil path for host-only URLs, which
      # Regex.run/3 rejects — a 500, not a 404.
      assert_raise FunctionClauseError, ~r/Regex\.run/, fn ->
        url = "https://derpibooru.org"
        get(conn, ~p"/api/v1/json/oembed?url=#{url}")
      end
    end

    test "crashes on an image id that exceeds the integer column range", %{conn: conn} do
      # NOTE: the extracted id is interpolated into the query unchecked, so
      # an id that does not fit in the id column raises instead of 404ing.
      assert_raise DBConnection.EncodeError, fn ->
        url = "https://derpibooru.org/images/99999999999999999999"
        get(conn, ~p"/api/v1/json/oembed?url=#{url}")
      end
    end
  end
end
