defmodule Philomena.PostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Posts` context.
  """

  import Philomena.AttributionFixtures

  alias Philomena.Posts

  @doc """
  Creates a reply post in `topic`, authored by `user` (anonymous
  attribution when `nil`).
  """
  def post_fixture(topic, user \\ nil, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{"body" => "Test post body"})

    {:ok, %{post: post}} = Posts.create_post(topic, attribution(user), attrs)

    post
  end
end
