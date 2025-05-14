defmodule Philomena.Images.QueryTest do
  alias Philomena.Labeled
  alias Philomena.Users.User
  alias Philomena.Filters.Filter
  import Philomena.FiltersFixtures
  import Philomena.TagsFixtures

  use Philomena.SearchSyntaxCase

  defp make_user(attrs) do
    %User{
      # Pretend that all users have the same ID. This doesn't influence the parser
      # logic because it doesn't load the users from the DB.
      id: 1,
      watched_tag_ids: [],
      watched_images_query_str: "",
      watched_images_exclude_str: "",
      no_spoilered_in_watched: false,
      current_filter: %Filter{spoilered_tag_ids: [], spoilered_complex_str: ""}
    }
    |> Map.merge(attrs)
  end

  test "search syntax" do
    users = [
      Labeled.new(:anon, nil),
      Labeled.new(:user, make_user(%{role: "user"})),
      Labeled.new(:assistant, make_user(%{role: "assistant"})),
      Labeled.new(:moderator, make_user(%{role: "moderator"})),
      Labeled.new(:admin, make_user(%{role: "admin"}))
    ]

    for id <- 10..14 do
      tag_fixture(%{id: id, name: "tag#{id}"})
    end

    system_filter =
      system_filter_fixture(%{
        id: 100,
        name: "System Filter",
        spoilered_tag_list: "tag10,tag11",
        hidden_tag_list: "tag12,tag13",
        hidden_complex_str: "truly AND complex"
      })

    assert_search_syntax(%{
      compile: &Philomena.Images.Query.compile/2,
      snapshot: "#{__DIR__}/search-syntax.json",
      contexts: %{
        user: users,
        watch: [true, false],
        filter: [true, false]
      },
      test_cases: [
        wildcard: [
          "*",
          "artist:*",
          "artist:artist1"
        ],
        operators: [
          "tag1 OR tag2",
          "tag1 AND tag2",
          "tag1 AND (tag2 OR tag3)"
        ],
        authenticated_user: [
          "my:faves",
          "my:watched"
        ],
        system_filter: [
          "filter_id:#{system_filter.id}"
        ],
        invalid_filters: [
          "filter_id:invalid_id",
          # non-existent filter
          "filter_id:9999"
        ]
      ]
    })
  end
end
