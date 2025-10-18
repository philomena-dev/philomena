defmodule Philomena.Avatars.Kind do
  use Ecto.Schema
  import Ecto.Changeset

  schema "avatar_kinds" do
    field :name, :string
  end

  @doc false
  def changeset(kind, attrs) do
    kind
    |> cast(attrs, [:name])
  end
end
