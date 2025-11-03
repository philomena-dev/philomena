defmodule Philomena.Avatars.Shape do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Avatars.Part

  schema "avatar_shapes" do
    belongs_to :avatar_part, Part

    field :shape, :string
    field :any_kind, :boolean, default: false
  end

  @doc false
  def changeset(shape, attrs) do
    shape
    |> cast(attrs, [:name, :avatar_part_id])
  end
end
