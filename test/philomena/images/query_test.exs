defmodule Philomena.Images.QueryTest do
  use ExUnit.Case, async: true

  alias Philomena.Images.Query

  @user %{
    id: 1,
    role: "user",
    watched_tag_ids: [],
    watched_images_query_str: nil,
    watched_images_exclude_str: nil,
    no_spoilered_in_watched: false
  }

  describe "compile/2 with my:upvotes" do
    test "returns a term query for the user's upvoter_ids" do
      assert {:ok, %{term: %{upvoter_ids: 1}}} = Query.compile("my:upvotes", user: @user)
    end

    test "returns an error for anonymous users" do
      assert {:error, _} = Query.compile("my:upvotes", user: nil)
    end
  end

  describe "compile/2 with my:subs" do
    test "returns a term query for the user's subscriber_ids" do
      assert {:ok, %{term: %{subscriber_ids: 1}}} = Query.compile("my:subs", user: @user)
    end

    test "returns an error for anonymous users" do
      assert {:error, _} = Query.compile("my:subs", user: nil)
    end
  end
end
