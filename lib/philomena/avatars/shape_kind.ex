defmodule Philomena.Avatars.ShapeKind do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Avatars.Kind
  alias Philomena.Avatars.Shape

  schema "avatar_shape_kinds" do
    belongs_to :avatar_kind, Kind
    belongs_to :avatar_shape, Shape
  end

  @doc false
  def changeset(shape_kind, attrs) do
    shape_kind
    |> cast(attrs, [:avatar_shape_id, :avatar_kind_id])
  end
end
