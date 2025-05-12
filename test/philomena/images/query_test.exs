defmodule Philomena.Images.UsersTest do
  alias Philomena.Images.Query

  use ExUnit.Case, async: true
  import AssertValue

  test "query" do
    queries = File.read!("query-tests.json")

    tree = Query.compile("*")

    assert_value tree == {:ok, %{match_all: %{}}}
  end
end
