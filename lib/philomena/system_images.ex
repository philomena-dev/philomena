defmodule Philomena.SystemImages do
  @moduledoc """
  The System Images context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.SystemImages.SystemImage
  alias Philomena.SystemImages.Uploader

  @protected_keys ["favicon.svg", "favicon.ico", "tagblocked.svg", "no_avatar.svg"]

  @doc """
  Returns the list of system images.

  ## Examples

      iex> list_system_images()
      [%SystemImage{}, ...]

  """
  def list_system_images do
    Repo.all(SystemImage)
  end

  @doc """
  Gets a single system_image.

  Raises `Ecto.NoResultsError` if the System Image does not exist.

  ## Examples

      iex> get_system_image!(123)
      %SystemImage{}

      iex> get_system_image!(456)
      ** (Ecto.NoResultsError)

  """
  def get_system_image!(id), do: Repo.get!(SystemImage, id)

  @doc """
  Gets a single system image by its key.

  Returns nil if the System Image does not exist.

  ## Examples

      iex> get_system_image_by_key("favicon.svg")
      %SystemImage{}

      iex> get_system_image_by_key("nonexistent.png")
      nil

  """
  def get_system_image_by_key(key), do: Repo.get_by(SystemImage, key: key)

  @doc """
  Creates a system image.

  ## Examples

      iex> create_system_image(%{key: "favicon.svg"})
      {:ok, %SystemImage{}}

      iex> create_system_image(%{key: "virus.exe"})
      {:error, %Ecto.Changeset{}}

  """
  def create_system_image(%{image: image} = attrs) do
    %SystemImage{}
    |> SystemImage.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, system_image} ->
        Uploader.upload_system_image(image, system_image.key)

        {:ok, system_image}

      error ->
        error
    end
  end

  @doc """
  Updates a system image without updating its image.

  ## Examples

      iex> update_system_image(system_image, %{key: "new_key.png"})
      {:ok, %SystemImage{}}

      iex> update_system_image(system_image, %{key: "virus.exe"})
      {:error, %Ecto.Changeset{}}

  """
  def update_system_image(%SystemImage{key: key} = system_image, _) when key in @protected_keys,
    do: {:error, system_image}

  def update_system_image(%SystemImage{} = system_image, attrs) do
    system_image
    |> SystemImage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the uploaded file for a system image.

  """
  def update_system_image_file(%SystemImage{key: key}, %{image: image}) do
    Uploader.upload_system_image(image, key)
  end

  @doc """
  Deletes a SystemImage.

  ## Examples

      iex> delete_system_image(system_image)
      {:ok, %SystemImage{}}

      iex> delete_system_image(system_image)
      {:error, %Ecto.Changeset{}}

  """
  def delete_system_image(%SystemImage{key: key} = system_image) when key in @protected_keys,
    do: {:error, system_image}

  def delete_system_image(%SystemImage{} = system_image) do
    Repo.delete(system_image)
  end
end
