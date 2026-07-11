defmodule PhilomenaWeb.UserAttributionPlugTest do
  @moduledoc """
  Unit tests for `PhilomenaWeb.UserAttributionPlug`.

  The plug now assigns BOTH the legacy `:attributes`
  keyword list (`[ip:, fingerprint:, user:]`) and the typed
  `%Philomena.Attribution.Actor{}` struct, built from the same three values.
  These tests pin that both assigns are present and consistent, and that the
  fingerprint source differs by path: the `_ses` cookie for normal requests,
  and `"a" <> crc32(user-agent)` for `/api/...` requests.
  """

  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias PhilomenaWeb.UserAttributionPlug
  alias Philomena.Attribution.Actor

  # A fresh conn (not the ConnCase default, which presets a random `_ses`
  # cookie) with a deterministic remote_ip, `_ses` cookie, user-agent, and the
  # `current_user` assign the plug reads.
  defp build_attribution_conn(opts) do
    path_info = Keyword.get(opts, :path_info, ["images"])
    current_user = Keyword.get(opts, :current_user)

    build_conn()
    |> Map.put(:remote_ip, {10, 0, 0, 1})
    |> Map.put(:path_info, path_info)
    |> put_req_cookie("_ses", "test-session-fingerprint")
    |> put_req_header("user-agent", "TestAgent/1.0")
    |> assign(:current_user, current_user)
  end

  describe "call/2 for a normal (non-API) request" do
    test "assigns both :attributes and :actor, consistent, with the _ses fingerprint" do
      {:ok, expected_ip} = EctoNetwork.INET.cast({10, 0, 0, 1})

      conn =
        build_attribution_conn(path_info: ["images"], current_user: nil)
        |> UserAttributionPlug.call([])

      attributes = conn.assigns.attributes
      assert attributes[:ip] == expected_ip
      assert attributes[:fingerprint] == "test-session-fingerprint"
      assert attributes[:user] == nil

      assert %Actor{} = actor = conn.assigns.actor
      assert actor.ip == attributes[:ip]
      assert actor.fingerprint == attributes[:fingerprint]
      assert actor.user == attributes[:user]
    end

    test "carries the logged-in user through to both assigns" do
      user = confirmed_user_fixture()

      conn =
        build_attribution_conn(path_info: ["images"], current_user: user)
        |> UserAttributionPlug.call([])

      assert conn.assigns.attributes[:user] == user
      assert conn.assigns.actor.user == user
      # Fingerprint still comes from the cookie on a non-API path.
      assert conn.assigns.actor.fingerprint == "test-session-fingerprint"
    end
  end

  describe "call/2 for an /api/... request" do
    test "derives the fingerprint from the user-agent, not the cookie" do
      expected_fingerprint = "a#{:erlang.crc32("TestAgent/1.0")}"

      conn =
        build_attribution_conn(path_info: ["api", "v1", "json", "images"], current_user: nil)
        |> UserAttributionPlug.call([])

      # NOTE: the API fingerprint ignores the _ses cookie entirely and is a
      # deterministic function of the user-agent string.
      assert conn.assigns.attributes[:fingerprint] == expected_fingerprint
      refute conn.assigns.attributes[:fingerprint] == "test-session-fingerprint"

      # Both assigns still agree.
      assert conn.assigns.actor.fingerprint == conn.assigns.attributes[:fingerprint]
    end
  end
end
