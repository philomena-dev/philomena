defmodule Philomena.SystemImages.SystemImage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "system_images" do
    field :key, :string
  end

  @doc false
  def changeset(system_image, attrs) do
    system_image
    |> cast(attrs, [:key])
  end
end
