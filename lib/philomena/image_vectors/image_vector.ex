defmodule Philomena.ImageVectors.ImageVector do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image

  schema "image_vectors" do
    belongs_to :image, Image
    field :type, :string
    field :features, {:array, :float}
  end

  @doc false
  def changeset(image_vector, attrs) do
    image_vector
    |> cast(attrs, [:type, :features])
    |> validate_required([:type, :features])
  end
end
