defmodule PhilomenaWeb.Image.ScrapeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Characterization tests: these pin the current observable behavior of the
  # endpoint (see CHARACTERIZATION-TESTS.md), they do not specify desired
  # behavior.
  #
  # The action passes the `url` param through PhilomenaProxy.Scrapers.scrape!/1
  # and renders the result as JSON. Any test that reaches a scraper which
  # performs outbound HTTP must stub PhilomenaProxy.Http at the Req.Test seam;
  # an unstubbed outbound request raises. For a generic host only the `Raw`
  # scraper does HTTP (a HEAD probe of the content-type); the others are
  # regex/host matches on the URL.

  describe "POST /images/scrape" do
    test "returns a scrape result for a directly-linked image (Raw scraper)", %{conn: conn} do
      # Raw.can_handle?/2 issues a HEAD and checks the raw content-type header
      # against a fixed allow-list, so it must be exactly "image/png" (no
      # "; charset=..." suffix).
      Req.Test.stub(PhilomenaProxy.Http, fn c ->
        c
        |> Plug.Conn.put_resp_header("content-type", "image/png")
        |> Plug.Conn.resp(200, "")
      end)

      url = "https://example.com/art/upload-test.png"

      conn = post(conn, ~p"/images/scrape", %{"url" => url})

      result = json_response(conn, 200)

      assert result["source_url"] == url
      assert result["author_name"] == ""
      assert result["description"] == ""
      assert [%{"url" => ^url, "camo_url" => camo_url}] = result["images"]
      assert is_binary(camo_url)
    end

    test "returns null when no scraper can handle the URL", %{conn: conn} do
      # A non-image content-type makes Raw.can_handle?/2 false, and no other
      # scraper matches a generic host, so scrape!/1 returns nil.
      Req.Test.stub(PhilomenaProxy.Http, fn c ->
        c
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.resp(200, "<html></html>")
      end)

      conn = post(conn, ~p"/images/scrape", %{"url" => "https://example.com/not-an-image"})

      # NOTE: a no-match scrape renders the JSON literal `null`, not an error.
      assert json_response(conn, 200) == nil
    end

    test "returns null for a URL with no host without any outbound request", %{conn: conn} do
      # NOTE: scrape!/1 short-circuits to nil when URI.parse/1 finds no host,
      # so no scraper runs and no HTTP stub is required.
      conn = post(conn, ~p"/images/scrape", %{"url" => "not a url"})

      assert json_response(conn, 200) == nil
    end

    test "returns null when the url parameter is missing", %{conn: conn} do
      # NOTE: a missing url becomes "" (nil |> to_string |> trim), which parses
      # to a hostless URI and returns nil. No HTTP stub required.
      conn = post(conn, ~p"/images/scrape")

      assert json_response(conn, 200) == nil
    end

    test "is reachable by logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/images/scrape", %{"url" => "not a url"})

      assert json_response(conn, 200) == nil
    end
  end
end
