defmodule PhilomenaMedia.Features do
  @moduledoc """
  Features are a set of 768 weighted classification outputs produced from a
  vision transformer (ViT). The individual classifications are arbitrary and
  not meaningful to analyze, but the vectors can be used to compare similarity
  between images using the cosine similarity measurement.

  Since cosine similarity is not a metric, it is substituted for normalized L2
  distance by the feature extractor; every vector that it returns is normalized,
  and traversing the k nearest neighbors in a vector space index will iterate
  vectors in the same order as their cosine similarity.
  """

  alias PhilomenaMedia.Remote

  @type t :: %__MODULE__{
          features: [float()]
        }

  defstruct [:features]

  @doc """
  Gets the features of the given image file.

  The image file must be in the PNG or JPEG format.

  > #### Info {: .info}
  >
  > Clients should prefer to use `PhilomenaMedia.Processors.features/2`, as it handles
  > media files of any type supported by this library, not just PNG or JPEG.

  ## Examples

      iex> Features.file("image.png")
      {:ok, %Features{features: [0.03156396001577377, -0.04559657722711563, ...]}}

      iex> Features.file("nonexistent.jpg")
      :error

  """
  @spec file(Path.t()) :: {:ok, t()} | :error
  def file(input) do
    case Remote.get_features(input) do
      {:ok, features} ->
        {:ok, %__MODULE__{features: features}}

      _error ->
        :error
    end
  end
end
