defmodule Philomena.QuickTags.Shipping do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.QuickTags.Tab

  schema "shipping_quick_tags" do
    belongs_to :quick_tag_tab, Tab

    field :category, :string
    field :implying, {:array, :string}, default: []
    field :not_implying, {:array, :string}, default: []
  end

  @doc false
  def changeset(tags, attrs) do
    tags
    |> cast(attrs, [:category, :implying, :not_implying])
  end
end
