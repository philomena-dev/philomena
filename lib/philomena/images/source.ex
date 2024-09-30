defmodule Philomena.Images.Source do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image

  @primary_key false
  schema "image_sources" do
    belongs_to :image, Image, primary_key: true
    field :source, :string, primary_key: true
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:source])
    |> validate_required([:source])
    |> validate_format(:source, ~r/\Ahttps?:\/\//)
    |> validate_length(:source, max: 255)
  end
end
