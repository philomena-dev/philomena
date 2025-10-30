defmodule Philomena.QuickTags.Tab do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quick_tag_tabs" do
    field :title, :string
    field :position, :integer
  end

  @doc false
  def changeset(tab, attrs) do
    tab
    |> cast(attrs, [:title, :position])
  end
end
