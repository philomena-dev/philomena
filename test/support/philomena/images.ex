defmodule Philomena.Test.Images do
  alias Philomena.Repo
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Test
  alias Philomena.Users.User

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

  @type image_ctx :: %{
          image: Image.t()
        }

  @spec create_image(%{user: User.t()}, map()) :: image_ctx()
  def create_image(ctx, attrs \\ %{}) do
    if Map.get(ctx, :async) do
      raise "Image creation in `async` mode is not supported because it spawns " <>
              "a background process that needs to access the DB connection checked out " <>
              "by the calling process."
    end

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
      user: ctx.user
    ]

    {:ok, %{image: image, upload_pid: upload_pid}} = Images.create_image(principal, attrs)

    # Wait for the upload process to finish. It should be fast enough in case if
    # the default `dummy.png` file is used, which is extremely small.
    upload_ref = Process.monitor(upload_pid)

    receive do
      {:DOWN, ^upload_ref, :process, ^upload_pid, _reason} ->
        Map.put(ctx, :image, image)
    end
  end

  def snap(%Image{} = image) do
    image_tags =
      image.tags
      |> Enum.map(&Test.Tags.snap/1)
      |> Enum.join(" ")

    "Image(#{image.id}): #{image_tags}"
  end
end
