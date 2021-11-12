defmodule Philomena.Layouts do
  @moduledoc """
  The Layouts context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Layouts.Layout

  @doc """
  Gets a single layout.

  ## Examples

      iex> get_layout!()
      %Layout{}

  """
  @spec get_layout!() :: Layout.t()
  def get_layout! do
    Repo.one!(Layout)
  end

  alias Philomena.Layouts.UserLayout
  alias Philomena.Users.User


  @doc """
  Gets a single user_layout.

  ## Examples

      iex> get_user_layout!(%User{})
      %UserLayout{}

  """
  @spec get_user_layout!(User.t()) :: UserLayout.t()
  def get_user_layout!(user) do
    UserLayout
    |> where(user_id: ^user.id)
    |> Repo.one!()
  end
end
