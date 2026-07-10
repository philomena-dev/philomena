defmodule Philomena.ArtistLinksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.ArtistLinks` context.
  """

  alias Philomena.ArtistLinks

  @doc """
  Creates an unverified artist link for `user` pointing at `tag` (which must
  be a creator-category tag - an `artist:`-prefixed `tag_fixture/1` name gets
  the `origin` category automatically).

  String-keyed attrs mirror the artist-link form (`"uri"`, `"public"`); a
  unique `"uri"` is supplied by default so repeated calls don't collide on
  the `[:uri, :tag_id, :user_id]` unique constraint.
  """
  def artist_link_fixture(user, tag, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "tag_name" => tag.name,
        "uri" => "https://example.com/artist#{System.unique_integer([:positive])}"
      })

    {:ok, artist_link} = ArtistLinks.create_artist_link(user, attrs)
    artist_link
  end

  @doc """
  Creates an artist link for `user`/`tag` and transitions it to the verified
  state (attributed to `user`, the way an admin verifying it would be
  recorded). The badge awarder tolerates the missing "Artist" badge in tests.
  """
  def verified_artist_link_fixture(user, tag, attrs \\ %{}) do
    artist_link = artist_link_fixture(user, tag, attrs)
    {:ok, artist_link} = ArtistLinks.verify_artist_link(artist_link, user)
    artist_link
  end
end
