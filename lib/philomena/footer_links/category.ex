defmodule Philomena.FooterLinks.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "footer_categories" do
    field :title, :string
    field :position, :integer
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:title, :position])
  end
end
