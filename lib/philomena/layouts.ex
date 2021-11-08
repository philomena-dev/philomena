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
end
