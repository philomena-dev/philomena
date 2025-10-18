defmodule Philomena.Avatars do
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo
  alias Philomena.Avatars.Kind
  alias Philomena.Avatars.Part
  alias Philomena.Avatars.Shape
  alias Philomena.Avatars.ShapeKind

  def get_kinds() do
    Repo.all(Kind)
  end

  def get_parts() do
    Repo.all(Part)
  end

  def get_shapes() do
    Repo.all(Shape)
  end

  def get_shape_kinds() do
    Repo.all(ShapeKind)
  end
end
