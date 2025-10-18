defmodule Philomena.Avatars.Part do
  use Ecto.Schema
  import Ecto.Changeset

  schema "avatar_parts" do
    field :name, :string
    field :priority, :integer, default: 1
  end

  @doc false
  def changeset(part, attrs) do
    part
    |> cast(attrs, [:name, :priority])
  end
end
