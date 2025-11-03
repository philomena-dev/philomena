defmodule Philomena.Rules.Rule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rules" do
    field :name, :string
    field :title, :string
    field :description, :string
    field :short_description, :string
    field :example, :string
    field :position, :integer, default: 1
    field :highlight, :boolean, default: false
    field :hidden, :boolean, default: false
    field :internal, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :name,
      :title,
      :description,
      :short_description,
      :example,
      :position,
      :highlight,
      :hidden,
      :internal
    ])
    |> validate_required([
      :name
    ])
  end
end
