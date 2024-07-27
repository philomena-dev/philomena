defmodule Philomena.Polls.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Topics.Topic
  alias Philomena.PollOptions.PollOption

  schema "polls" do
    belongs_to :topic, Topic
    has_many :options, PollOption

    field :title, :string
    field :vote_method, :string
    field :active_until, PhilomenaQuery.Ecto.RelativeDate
    field :total_votes, :integer, default: 0

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [:title, :active_until, :vote_method])
    |> validate_required([:title, :active_until, :vote_method])
    |> validate_length(:title, max: 140, count: :bytes)
    |> validate_inclusion(:vote_method, ["single", "multiple"])
    |> cast_assoc(:options, required: true, with: &PollOption.creation_changeset/2)
    |> validate_length(:options, min: 2, max: 20)
    |> ignore_if_blank()
  end

  defp ignore_if_blank(%{valid?: false, changes: changes} = changeset) when changes == %{},
    do: %{changeset | action: :ignore}

  defp ignore_if_blank(changeset),
    do: changeset
end
