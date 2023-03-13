defmodule Philomena.EthereumChanges do
  @moduledoc """
  The EthereumChanges context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.EthereumChanges.EthereumChange

  @doc """
  Returns the list of ethereum_changes.

  ## Examples

      iex> list_ethereum_changes()
      [%EthereumChange{}, ...]

  """
  def list_ethereum_changes do
    Repo.all(EthereumChange)
  end

  @doc """
  Gets a single ethereum_change.

  Raises `Ecto.NoResultsError` if the User name change does not exist.

  ## Examples

      iex> get_ethereum_change!(123)
      %EthereumChange{}

      iex> get_ethereum_change!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ethereum_change!(id), do: Repo.get!(EthereumChange, id)

  @doc """
  Creates a ethereum_change.

  ## Examples

      iex> create_ethereum_change(%{field: value})
      {:ok, %EthereumChange{}}

      iex> create_ethereum_change(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ethereum_change(attrs \\ %{}) do
    %EthereumChange{}
    |> EthereumChange.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ethereum_change.

  ## Examples

      iex> update_ethereum_change(ethereum_change, %{field: new_value})
      {:ok, %EthereumChange{}}

      iex> update_ethereum_change(ethereum_change, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ethereum_change(%EthereumChange{} = ethereum_change, attrs) do
    ethereum_change
    |> EthereumChange.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a EthereumChange.

  ## Examples

      iex> delete_ethereum_change(ethereum_change)
      {:ok, %EthereumChange{}}

      iex> delete_ethereum_change(ethereum_change)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ethereum_change(%EthereumChange{} = ethereum_change) do
    Repo.delete(ethereum_change)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ethereum_change changes.

  ## Examples

      iex> change_ethereum_change(ethereum_change)
      %Ecto.Changeset{source: %EthereumChange{}}

  """
  def change_ethereum_change(%EthereumChange{} = ethereum_change) do
    EthereumChange.changeset(ethereum_change, %{})
  end
end
