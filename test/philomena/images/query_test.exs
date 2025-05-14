defmodule Philomena.Images.QueryTest do
  alias Philomena.Labeled
  import Philomena.UsersFixtures
  import Philomena.FiltersFixtures
  import Philomena.TagsFixtures

  use Philomena.SearchSyntaxCase

  defp make_user(attrs) do
    # Set the user ID to a dummy value to make sure it's consistent between
    # the test cases of different users. This way we avoid generating extra
    # test cases in the snapshot that just differ by user ID.
    # |> Map.put(:id, 1)
    attrs |> user_fixture()
  end

  test "search syntax" do
    users = [
      Labeled.new(:anon, nil),
      Labeled.new(:user, make_user(%{confirmed: true})),
      Labeled.new(:assistant, make_user(%{role: "assistant"})),
      Labeled.new(:moderator, make_user(%{role: "moderator"})),
      Labeled.new(:admin, make_user(%{role: "admin"}))
    ]

    for id <- 10..14 do
      tag_fixture(%{id: id, name: "tag#{id}"})
    end
    |> Enum.to_list()

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
          "artist:mare"
        ],
        operators: [
          "safe OR pony",
          "safe AND pony",
          "safe AND (solo OR pony)"
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
