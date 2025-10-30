defmodule Philomena.QuickTags.Default do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.QuickTags.Tab

  schema "default_quick_tags" do
    belongs_to :quick_tag_tab, Tab

    field :category, :string
    field :tags, {:array, :string}
  end

  @doc false
  def changeset(tags, attrs) do
    tags
    |> cast(attrs, [:category, :tags])
  end
end
