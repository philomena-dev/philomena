defmodule Philomena.TopicsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Topics` context.
  """

  import Philomena.AttributionFixtures

  alias Philomena.Topics

  def unique_topic_title, do: "Test Topic #{System.unique_integer([:positive])}"

  @doc """
  Creates a topic (with its required first post) in `forum`, authored by
  `user` (anonymous attribution when `nil`).

  `attrs` are merged into the string-keyed params map the way the topic
  controller would submit them; pass `"posts" => %{"0" => %{"body" => ...}}`
  to override the first post body.

  Returns the topic with `posts: [first_post]` loaded.
  """
  def topic_fixture(forum, user \\ nil, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "title" => unique_topic_title(),
        "anonymous" => "false",
        "posts" => %{"0" => %{"body" => "Test topic body"}}
      })

    {:ok, %{topic: topic}} = Topics.create_topic(forum, attribution(user), attrs)

    topic
  end
end
