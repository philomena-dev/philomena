defmodule Philomena.ModNotesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.ModNotes` context.
  """

  alias Philomena.ModNotes

  @doc """
  Creates a mod note authored by `author` against a fresh
  `confirmed_user_fixture/0`.

  Notes are created through the context so `moderator_id` is set to the passed
  `author`; the edit/update/delete abilities are scoped to that id (a
  moderator may only touch their own notes, admins may touch any).
  """
  def mod_note_fixture(author, attrs \\ %{}) do
    target = Philomena.UsersFixtures.confirmed_user_fixture()

    {:ok, note} =
      ModNotes.create_mod_note(
        author,
        Enum.into(attrs, %{
          "notable_type" => "User",
          "notable_id" => target.id,
          "body" => "Keeping an eye on this one"
        })
      )

    note
  end
end
