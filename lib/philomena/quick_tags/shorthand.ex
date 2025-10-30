defmodule Philomena.QuickTags.Shorthand do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.QuickTags.ShorthandCategory

  schema "shorthand_quick_tags" do
    belongs_to :shorthand_quick_tag_category, ShorthandCategory

    field :shorthand, :string
    field :tag, :string
  end

  @doc false
  def changeset(shorthand, attrs) do
    shorthand
    |> cast(attrs, [:shorthand, :tag])
  end
end
