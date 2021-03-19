defmodule Philomena.Images.ImageView do
  use Ecto.Schema

  @primary_key false

  schema "image_views" do
    belongs_to :image, Philomena.Images.Image
    field :views_count, :integer, default: 0
  end
end
