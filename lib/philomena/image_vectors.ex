defmodule Philomena.ImageVectors do
  @moduledoc """
  The ImageVectors context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.ImageVectors.ImageVector

  @doc """
  Gets a single image_vector.

  Raises `Ecto.NoResultsError` if the Image vector does not exist.

  ## Examples

      iex> get_image_vector!(123)
      %ImageVector{}

      iex> get_image_vector!(456)
      ** (Ecto.NoResultsError)

  """
  def get_image_vector!(id), do: Repo.get!(ImageVector, id)

  @doc """
  Creates a image_vector.

  ## Examples

      iex> create_image_vector(%{field: value})
      {:ok, %ImageVector{}}

      iex> create_image_vector(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_image_vector(image, attrs \\ %PhilomenaMedia.Features{}) do
    %ImageVector{image_id: image.id}
    |> ImageVector.changeset(Map.from_struct(attrs))
    |> Repo.insert()
  end

  @doc """
  Updates a image_vector.

  ## Examples

      iex> update_image_vector(image_vector, %{field: new_value})
      {:ok, %ImageVector{}}

      iex> update_image_vector(image_vector, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_image_vector(%ImageVector{} = image_vector, attrs) do
    image_vector
    |> ImageVector.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a image_vector.

  ## Examples

      iex> delete_image_vector(image_vector)
      {:ok, %ImageVector{}}

      iex> delete_image_vector(image_vector)
      {:error, %Ecto.Changeset{}}

  """
  def delete_image_vector(%ImageVector{} = image_vector) do
    Repo.delete(image_vector)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking image_vector changes.

  ## Examples

      iex> change_image_vector(image_vector)
      %Ecto.Changeset{data: %ImageVector{}}

  """
  def change_image_vector(%ImageVector{} = image_vector, attrs \\ %{}) do
    ImageVector.changeset(image_vector, attrs)
  end
end
