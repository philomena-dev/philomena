defmodule Philomena.BadgesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Badges` context.
  """

  alias Philomena.Badges
  alias Philomena.Badges.Badge
  alias Philomena.Repo

  def unique_badge_title, do: "Test Badge #{System.unique_integer([:positive])}"

  @doc """
  Creates a badge.

  `Badges.create_badge/1` runs the SVG upload pipeline
  (`persist_upload/1` crashes without a real uploaded file), which
  characterization tests don't need — so this inserts the row directly with
  the image filename set the way the uploader would leave it.
  """
  def badge_fixture(attrs \\ %{}) do
    %Badge{image: "test.svg"}
    |> Badge.changeset(Enum.into(attrs, %{title: unique_badge_title()}))
    |> Repo.insert!()
  end

  @doc """
  Awards `badge` (a fresh `badge_fixture/0` when `nil`) to `user`, awarded
  by `creator`.
  """
  def badge_award_fixture(creator, user, badge \\ nil, attrs \\ %{}) do
    badge = badge || badge_fixture()

    {:ok, award} =
      Badges.create_badge_award(creator, user, Enum.into(attrs, %{badge_id: badge.id}))

    award
  end
end
