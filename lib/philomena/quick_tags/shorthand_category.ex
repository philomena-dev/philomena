defmodule Philomena.QuickTags.ShorthandCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.QuickTags.Tab

  schema "shorthand_quick_tag_categories" do
    belongs_to :quick_tag_tab, Tab

    field :category, :string
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:category])
  end
end
