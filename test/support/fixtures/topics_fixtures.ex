defmodule Philomena.TopicsFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the `Philomena.Topics` context.
  """

  alias Philomena.Topics
  alias Philomena.{AttributionFixtures, ForumsFixtures, UsersFixtures}

  def unique_name do
    for _ <- 1..32, into: <<>>, do: <<Enum.random(?a..?z)>>
  end

  def topic_fixture(opts \\ []) do
    forum = Keyword.get_lazy(opts, :forum, fn -> ForumsFixtures.forum_fixture() end)
    user = Keyword.get_lazy(opts, :user, fn -> UsersFixtures.user_fixture() end)
    attribution = AttributionFixtures.attribution_fixture(user)

    {:ok, %{topic: topic}} = Topics.create_topic(forum, attribution, topic_attrs())

    topic
  end

  def topic_attrs do
    %{
      title: unique_name(),
      anonymous: false,
      posts: [post_attrs()]
    }
  end

  def post_attrs do
    %{body: unique_name()}
  end
end
