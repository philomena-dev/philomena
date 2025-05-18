defmodule Philomena.Test.Images do
  alias Philomena.Repo
  alias Philomena.Images.Image
  alias Philomena.Images

  import Ecto.Query

  @doc """
  Loads an image by ID and preloads the specified associations.
  Raises `Ecto.NoResultsError` if the image is not found.
  """
  @spec load_image!(integer(), preload: [atom()]) :: Image.t()
  def load_image!(id, opts) do
    Image
    |> where(id: ^id)
    |> preload(^Keyword.get(opts, :preload, []))
    |> Repo.one()
  end

  @spec create_image(User.t(), map()) :: Images.Image.t()
  def create_image(uploader, attrs \\ %{}) do
    attrs =
      %{
        "image" => %Plug.Upload{
          path: "#{__DIR__}/dummy.png",
          filename: "dummy.png",
          content_type: "image/png"
        },
        "tag_input" => "safe,a,b",
        "sources" => ["https://localhost/images_fixtures.ex"]
      }
      |> Map.merge(attrs)

    principal = [
      user: uploader
    ]

    {:ok, %{image: image}} = Images.create_image(principal, attrs)

    image
  end
end
