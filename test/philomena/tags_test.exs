defmodule Philomena.TagsTest do
  use Philomena.DataCase, async: true

  alias Philomena.Tags
  alias Philomena.Tags.Tag

  @limit Tag.name_length_limit()

  describe "create_tag/1 name length limit" do
    test "accepts a name of exactly the limit" do
      name = String.duplicate("a", @limit)

      assert {:ok, %Tag{name: ^name}} = Tags.create_tag(%{name: name})
    end

    test "rejects a name over the limit" do
      name = String.duplicate("a", @limit + 1)

      assert {:error, changeset} = Tags.create_tag(%{name: name})

      assert %{name: ["should be at most #{@limit} byte(s)"]} == errors_on(changeset)
    end

    test "counts bytes, not characters" do
      # 130 characters of "é" (2 bytes each in UTF-8) = 260 bytes
      name = String.duplicate("é", 130)

      assert {:error, changeset} = Tags.create_tag(%{name: name})
      assert %{name: [_message]} = errors_on(changeset)
    end
  end

  describe "parse_tag_list/1" do
    test "drops names over the limit and keeps the rest" do
      oversized = String.duplicate("a", @limit + 1)

      assert Tag.parse_tag_list("safe, #{oversized}, cute") == ["safe", "cute"]
    end

    test "keeps names of exactly the limit" do
      name = String.duplicate("a", @limit)

      assert Tag.parse_tag_list(name) == [name]
    end
  end

  describe "get_or_create_tags/1" do
    test "does not create tags with oversized names" do
      oversized = String.duplicate("a", @limit + 1)

      tags = Tags.get_or_create_tags("safe, #{oversized}")

      assert [%Tag{name: "safe"}] = tags
      assert Tags.get_tag_by_name(oversized) == nil
    end
  end
end
