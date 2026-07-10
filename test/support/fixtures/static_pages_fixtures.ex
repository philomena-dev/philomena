defmodule Philomena.StaticPagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.StaticPages` context.
  """

  alias Philomena.StaticPages

  def unique_static_page_slug, do: "test-page-#{System.unique_integer([:positive])}"

  @doc """
  Creates a static page (with its initial version, attributed to `user`).

  `StaticPages.create_static_page/2` requires a user for the version row, so
  one must be provided.
  """
  def static_page_fixture(user, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        title: "Test Page ##{unique}",
        slug: unique_static_page_slug(),
        body: "Test page body"
      })

    {:ok, %{static_page: static_page}} = StaticPages.create_static_page(user, attrs)

    static_page
  end
end
