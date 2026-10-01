defmodule Philomena.Images.SearchTest do
  @moduledoc """
  Context-level tests for `Philomena.Images.Search` and its `Scope` struct.

  The module builds OpenSearch definitions scoped to a viewer: the default
  listing query with its upload delay, the deleted/hidden display switches
  driven by the "del"/"hidden" params, the "sf"/"sd" sort mapping, and
  prev/next navigation. Query builders return `{definition, tags}` where the
  tags are the raw `Tag` records a tag search names.

  Search-backed behavior is asserted against the real OpenSearch index;
  `parse_sort/2` and the `Scope` struct are pure and asserted directly.
  """

  use Philomena.DataCase, async: false

  @moduletag :search

  import Philomena.ImagesFixtures
  import Philomena.AttributionFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images.Search
  alias Philomena.Images.Search.Scope
  alias Philomena.Images.Image
  alias Philomena.Images.Query
  alias Philomena.ImageHides.ImageHide
  alias Philomena.Tags.Tag
  alias Philomena.Repo
  alias PhilomenaQuery.Search, as: SearchClient
  alias PhilomenaQuery.SearchHelpers

  @pagination %{page_number: 1, page_size: 25}

  setup do
    SearchClient.clear_index!(Image)
    :ok
  end

  # The compiled filter body the web layer's ImageFilterPlug produces for a
  # viewer with no active filter: an empty tag_ids exclusion plus a pair of
  # match_none complex clauses, so it excludes nothing.
  defp default_filter do
    %{
      bool: %{
        should: [
          %{terms: %{tag_ids: []}},
          %{bool: %{should: [%{match_none: %{}}, %{match_none: %{}}]}}
        ]
      }
    }
  end

  defp scope(overrides \\ []) do
    Scope.new(
      Keyword.get(overrides, :filter, default_filter()),
      Keyword.get(overrides, :pagination, @pagination),
      Keyword.get(overrides, :params, %{})
    )
  end

  defp result_ids(definition) do
    definition
    |> Search.execute()
    |> Map.fetch!(:entries)
    |> Enum.map(& &1.id)
  end

  defp hides_image!(image, user) do
    Repo.insert!(%ImageHide{image_id: image.id, user_id: user.id})
  end

  defp seconds_ago(seconds) do
    DateTime.utc_now()
    |> DateTime.add(-seconds, :second)
    |> DateTime.truncate(:second)
  end

  defp hours_ago(hours), do: seconds_ago(hours * 3600)

  describe "default_query/2 and execute/2" do
    test "excludes images created less than three minutes ago from an anonymous viewer" do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} = Search.default_query(actor(), scope())

      refute image.id in result_ids(definition)
    end

    test "includes older images for an anonymous viewer" do
      image = image_fixture(created_at: hours_ago(1))
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} = Search.default_query(actor(), scope())

      assert image.id in result_ids(definition)
    end

    test "includes recent images for a user who disabled the upload delay" do
      user = confirmed_user_fixture()

      settings =
        user.settings
        |> Ecto.Changeset.change(delay_home_images: false)
        |> Repo.update!()

      user = %{user | settings: settings}
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} = Search.default_query(actor(user), scope())

      assert image.id in result_ids(definition)
    end

    test "excludes recent images from a user with the default upload delay" do
      user = confirmed_user_fixture()
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} = Search.default_query(actor(user), scope())

      refute image.id in result_ids(definition)
    end
  end

  describe "deleted/hidden switches" do
    test "an anonymous viewer never sees hidden images" do
      image = image_fixture(hidden_from_users: true)
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} = Search.query(actor(), scope(), %{match_all: %{}})

      refute image.id in result_ids(definition)
    end

    # The del switches only take effect for viewers who can hide images; a
    # non-privileged viewer always gets the hidden_from_users exclusion no
    # matter what del says.
    test "an anonymous viewer passing del=1 still does not see hidden images" do
      image = image_fixture(hidden_from_users: true)
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} =
        Search.query(actor(), scope(params: %{"del" => "1"}), %{match_all: %{}})

      refute image.id in result_ids(definition)
    end

    # NOTE: a viewer who can :hide images (admin here) still has hidden images
    # excluded by default; only del=1/only/deleted reveal them.
    test "an admin does not see hidden images by default" do
      admin = admin_user_fixture()
      image = image_fixture(hidden_from_users: true)
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} = Search.query(actor(admin), scope(), %{match_all: %{}})

      refute image.id in result_ids(definition)
    end

    test "an admin passing del=1 sees hidden images" do
      admin = admin_user_fixture()
      hidden = image_fixture(hidden_from_users: true)
      visible = image_fixture()
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} =
        Search.query(actor(admin), scope(params: %{"del" => "1"}), %{match_all: %{}})

      ids = result_ids(definition)
      assert hidden.id in ids
      assert visible.id in ids
    end

    test "an admin passing del=only sees only hidden images" do
      admin = admin_user_fixture()
      hidden = image_fixture(hidden_from_users: true)
      visible = image_fixture()
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} =
        Search.query(actor(admin), scope(params: %{"del" => "only"}), %{match_all: %{}})

      ids = result_ids(definition)
      assert hidden.id in ids
      refute visible.id in ids
    end

    # NOTE: del=deleted places the duplicate_id existence check in must_not, so
    # it excludes hidden images that have a duplicate and shows the hidden
    # images that do not - the inverse of "images that have a duplicate".
    test "an admin passing del=deleted sees hidden images without a duplicate" do
      admin = admin_user_fixture()
      original = image_fixture()
      duplicate = image_fixture(hidden_from_users: true, duplicate_id: original.id)
      hidden_non_dupe = image_fixture(hidden_from_users: true)
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} =
        Search.query(actor(admin), scope(params: %{"del" => "deleted"}), %{match_all: %{}})

      ids = result_ids(definition)
      assert hidden_non_dupe.id in ids
      refute duplicate.id in ids
    end

    # A moderator can hide images, so del=1 reveals them.
    test "a moderator passing del=1 sees hidden images" do
      moderator = moderator_user_fixture()
      image = image_fixture(hidden_from_users: true)
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} =
        Search.query(actor(moderator), scope(params: %{"del" => "1"}), %{match_all: %{}})

      assert image.id in result_ids(definition)
    end

    # A moderator can :hide images, so del=only shows only hidden ones.
    test "a moderator passing del=only sees only hidden images" do
      moderator = moderator_user_fixture()
      hidden = image_fixture(hidden_from_users: true)
      visible = image_fixture()
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} =
        Search.query(actor(moderator), scope(params: %{"del" => "only"}), %{match_all: %{}})

      ids = result_ids(definition)
      assert hidden.id in ids
      refute visible.id in ids
    end

    test "unapproved images are excluded even for an admin passing del=1" do
      admin = admin_user_fixture()
      image = image_fixture(approved: false)
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} =
        Search.query(actor(admin), scope(params: %{"del" => "1"}), %{match_all: %{}})

      refute image.id in result_ids(definition)
    end
  end

  describe "maybe_custom_hide" do
    test "a user's own hidden images are excluded by default" do
      user = confirmed_user_fixture()
      image = image_fixture()
      hides_image!(image, user)
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} = Search.query(actor(user), scope(), %{match_all: %{}})

      refute image.id in result_ids(definition)
    end

    test "a user's own hidden images are included with hidden=1" do
      user = confirmed_user_fixture()
      image = image_fixture()
      hides_image!(image, user)
      SearchHelpers.reindex_all!(Image)

      {definition, _tags} =
        Search.query(actor(user), scope(params: %{"hidden" => "1"}), %{match_all: %{}})

      assert image.id in result_ids(definition)
    end
  end

  describe "search_string/3" do
    test "returns {:ok, {definition, tags}} for a valid query naming no tag" do
      assert {:ok, {definition, tags}} = Search.search_string(actor(), scope(), "*")

      assert is_map(definition)
      assert tags == []
    end

    test "returns the raw Tag record a single-tag query names" do
      _image = image_fixture(tags: "safe")

      assert {:ok, {_definition, tags}} = Search.search_string(actor(), scope(), "safe")

      assert [%Tag{} = tag] = tags
      assert tag.name == "safe"
      # The raw schema struct is returned, not a rendered presentation map.
      assert is_integer(tag.id)
    end

    test "returns {:error, msg} for a malformed query" do
      assert {:error, msg} = Search.search_string(actor(), scope(), "width.gte:abc")
      assert is_binary(msg)
    end
  end

  describe "parse_sort/2" do
    @query %{match_all: %{}}

    test "an allowed field sorts by that field and then id" do
      assert %{query: @query, sorts: [%{"score" => "desc"}, %{"id" => "desc"}]} =
               Search.parse_sort(%{"sf" => "score"}, @query)
    end

    test "the sd parameter selects the direction" do
      assert %{sorts: [%{"score" => "asc"}, %{"id" => "asc"}]} =
               Search.parse_sort(%{"sf" => "score", "sd" => "asc"}, @query)
    end

    test "the id field sorts by id alone" do
      assert %{query: @query, sorts: [%{"id" => "desc"}]} =
               Search.parse_sort(%{"sf" => "id"}, @query)
    end

    test "an unknown field falls back to first_seen_at" do
      assert %{sorts: [%{"first_seen_at" => "desc"}, %{"id" => "desc"}]} =
               Search.parse_sort(%{"sf" => "bogus"}, @query)
    end

    test "a missing field falls back to first_seen_at" do
      assert %{sorts: [%{"first_seen_at" => "desc"}, %{"id" => "desc"}]} =
               Search.parse_sort(%{}, @query)
    end

    test "random:seed wraps the query in a seeded function_score" do
      result = Search.parse_sort(%{"sf" => "random:12345"}, @query)

      assert %{
               function_score: %{
                 query: @query,
                 random_score: %{seed: 12_345, field: :id},
                 boost_mode: :replace
               }
             } = result.query

      assert result.sorts == [%{"_score" => "desc"}, %{"id" => "desc"}]
    end

    test "random:seed is deterministic for a fixed seed" do
      assert Search.parse_sort(%{"sf" => "random:42"}, @query) ==
               Search.parse_sort(%{"sf" => "random:42"}, @query)
    end

    test "gallery_id:n produces a nested gallery-position sort" do
      assert %{
               query: @query,
               sorts: [
                 %{
                   "galleries.position" => %{
                     order: "desc",
                     nested: %{path: :galleries, filter: %{term: %{"galleries.id" => 7}}}
                   }
                 },
                 %{"id" => "desc"}
               ]
             } = Search.parse_sort(%{"sf" => "gallery_id:7"}, @query)
    end

    test "an invalid gallery id yields empty sorts" do
      assert %{query: @query, sorts: []} =
               Search.parse_sort(%{"sf" => "gallery_id:abc"}, @query)
    end
  end

  describe "find_consecutive/3" do
    setup do
      {:ok, compiled} = Query.compile("*", user: nil)

      older = image_fixture(first_seen_at: seconds_ago(2 * 86_400))
      newer = image_fixture(first_seen_at: seconds_ago(86_400))
      SearchHelpers.reindex_all!(Image)

      %{compiled: compiled, older: older, newer: newer}
    end

    test "rel=next finds the older image", %{compiled: compiled, older: older, newer: newer} do
      result =
        Search.find_consecutive(actor(), scope(params: %{"rel" => "next"}), newer, compiled)

      assert {image, hit} = result
      assert image.id == older.id
      assert is_map(hit)
      assert Map.has_key?(hit, "sort")
    end

    test "rel=prev finds the newer image", %{compiled: compiled, older: older, newer: newer} do
      result =
        Search.find_consecutive(actor(), scope(params: %{"rel" => "prev"}), older, compiled)

      assert {image, _hit} = result
      assert image.id == newer.id
    end

    test "returns nil at the end of the sequence", %{compiled: compiled, older: older} do
      assert Search.find_consecutive(actor(), scope(params: %{"rel" => "next"}), older, compiled) ==
               nil
    end

    test "uses a provided cursor for a non-default sort with tied sort values", %{
      compiled: compiled
    } do
      sort_scope = scope(params: %{"sf" => "score", "sd" => "desc"})
      {definition, _tags} = Search.query(actor(), sort_scope, %{match_all: %{}})

      %{entries: [{first, first_hit}, {second, second_hit} | _]} =
        Search.execute(definition, hits: true)

      assert first_hit["sort"] |> hd() == second_hit["sort"] |> hd()

      cursor = Enum.map(first_hit["sort"], &to_string/1)
      navigation_scope = scope(params: %{"sf" => "score", "rel" => "next", "sort" => cursor})

      assert {adjacent, _hit} =
               Search.find_consecutive(actor(), navigation_scope, first, compiled)

      assert adjacent.id == second.id
    end
  end

  describe "Scope struct" do
    test "new stores the filter and pagination" do
      scope = Scope.new(%{match_all: %{}}, @pagination)

      assert scope.filter == %{match_all: %{}}
      assert scope.pagination == @pagination
    end

    test "casts the search_after sort cursor as a string array" do
      scope = Scope.new(%{match_all: %{}}, @pagination, %{"sort" => ["123", "456"]})

      assert scope.sort == ["123", "456"]
    end

    test "defaults params and pagination" do
      scope = Scope.new(%{match_all: %{}}, @pagination)

      assert scope.q == nil
      assert scope.pagination == %{page_number: 1, page_size: 25}
    end
  end
end
