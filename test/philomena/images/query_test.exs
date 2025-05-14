defmodule Philomena.Images.QueryTest do
  alias Philomena.Labeled

  use Philomena.SearchSyntaxCase

  test "search syntax" do
    assert_search_syntax(%{
      compile: &Philomena.Images.Query.compile/2,
      snapshot: "#{__DIR__}/search-syntax.json",
      contexts: %{
        user: [
          Labeled.new(:anon, nil),
          Labeled.new(:user, %{id: "{user_id}", role: "user"}),
          Labeled.new(:assistant, %{id: "{user_id}", role: "assistant"}),
          Labeled.new(:moderator, %{id: "{user_id}", role: "moderator"}),
          Labeled.new(:admin, %{id: "{user_id}", role: "admin"})
        ],
        watch: [true, false]
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
          "my:faves"
        ]
      ]
    })
  end
end
