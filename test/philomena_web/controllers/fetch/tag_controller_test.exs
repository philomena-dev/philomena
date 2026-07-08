defmodule PhilomenaWeb.Fetch.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Characterization tests: these pin the current observable behavior of the
  # endpoint (see CHARACTERIZATION-TESTS.md), they do not specify desired
  # behavior.
  #
  # The action loads up to 50 tags by id from Postgres and renders them as
  # JSON. This is a read-only route with no failure-path write to test.

  import Philomena.TagsFixtures

  describe "GET /fetch/tags" do
    test "returns matching tags by id", %{conn: conn} do
      tag = tag_fixture(name: "safe")
      other = tag_fixture(name: "solo")

      conn = get(conn, ~p"/fetch/tags?#{[ids: [tag.id, other.id]]}")

      assert %{"tags" => tags} = json_response(conn, 200)

      tags = Enum.sort_by(tags, & &1["id"])

      assert tags ==
               [
                 %{
                   "id" => tag.id,
                   "name" => "safe",
                   "images" => tag.images_count,
                   "spoiler_image_uri" => nil
                 },
                 %{
                   "id" => other.id,
                   "name" => "solo",
                   "images" => other.images_count,
                   "spoiler_image_uri" => nil
                 }
               ]
               |> Enum.sort_by(& &1["id"])
    end

    test "renders the tag_url_root-prefixed spoiler image uri when set", %{conn: conn} do
      tag = tag_fixture(name: "spoilered")

      {:ok, tag} =
        tag
        |> Ecto.Changeset.change(image: "spoiler.png")
        |> Philomena.Repo.update()

      conn = get(conn, ~p"/fetch/tags?#{[ids: [tag.id]]}")

      assert %{"tags" => [%{"spoiler_image_uri" => uri}]} = json_response(conn, 200)
      # NOTE: prefixed with the configured :tag_url_root (e.g. "/tag-img").
      assert uri =~ "/spoiler.png"
    end

    test "returns an empty list for ids that match nothing", %{conn: conn} do
      conn = get(conn, ~p"/fetch/tags?#{[ids: [999_999_999]]}")

      assert json_response(conn, 200) == %{"tags" => []}
    end

    test "raises for an empty ids list", %{conn: conn} do
      # NOTE: an empty list serializes to no query param at all, so the request
      # arrives with no `ids` key and hits the same no-clause raise as a
      # missing parameter.
      assert_raise Phoenix.ActionClauseError, fn ->
        get(conn, ~p"/fetch/tags?#{[ids: []]}")
      end
    end

    test "caps the number of returned tags at 50", %{conn: conn} do
      tags = for i <- 1..60, do: tag_fixture(name: "cap tag #{i}")
      ids = Enum.map(tags, & &1.id)

      conn = get(conn, ~p"/fetch/tags?#{[ids: ids]}")

      # NOTE: the controller takes only the first 50 ids before querying.
      assert %{"tags" => returned} = json_response(conn, 200)
      assert length(returned) == 50
    end

    test "raises when the ids parameter is missing", %{conn: conn} do
      # NOTE: index/2 only clauses on an `ids` list param, so a request without
      # one has no matching function clause and raises (a 500), rather than
      # returning an empty list.
      assert_raise Phoenix.ActionClauseError, fn ->
        get(conn, ~p"/fetch/tags")
      end
    end

    test "raises when the ids parameter is not a list", %{conn: conn} do
      assert_raise Phoenix.ActionClauseError, fn ->
        get(conn, ~p"/fetch/tags?ids=5")
      end
    end

    test "is reachable by logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture(name: "reachable")

      conn = get(conn, ~p"/fetch/tags?#{[ids: [tag.id]]}")

      assert %{"tags" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == tag.id
    end
  end
end
