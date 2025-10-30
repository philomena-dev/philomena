defmodule Philomena.QuickTags.Season do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.QuickTags.Tab

  schema "season_quick_tags" do
    belongs_to :quick_tag_tab, Tab

    field :category, :string
    field :episode, :integer
    field :tag, :string
  end

  @doc false
  def changeset(tags, attrs) do
    tags
    |> cast(attrs, [:category, :episode, :tag])
  end
end
