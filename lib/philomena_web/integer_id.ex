defmodule PhilomenaWeb.IntegerId do
  @moduledoc """
  Parsing of integer ids taken straight from request paths and query strings.

  Interpolating an unparsed path segment into `where(id: ^id)` raises rather
  than returning no rows: `Ecto.Query.CastError` for a non-integer, and
  `DBConnection.EncodeError` for a value too large for the `integer` column.
  Callers use `parse/1` to turn both into an ordinary "no such row".
  """

  # Bounds of the Postgres `integer` (int4) columns these ids are stored in.
  @int_min -2_147_483_648
  @int_max 2_147_483_647

  @doc """
  Parses an id that an `integer` column could hold.

  Accepts an integer, or a string that is entirely an integer literal. Returns
  `:error` for anything else, including values outside the column's range.

  ## Examples

      iex> PhilomenaWeb.IntegerId.parse("42")
      {:ok, 42}

      iex> PhilomenaWeb.IntegerId.parse("not-a-number")
      :error

      iex> PhilomenaWeb.IntegerId.parse("99999999999999999999")
      :error

  """
  @spec parse(any()) :: {:ok, integer()} | :error
  def parse(id) when is_integer(id) do
    if in_range?(id), do: {:ok, id}, else: :error
  end

  def parse(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> parse(int)
      _ -> :error
    end
  end

  def parse(_id), do: :error

  defp in_range?(id), do: id >= @int_min and id <= @int_max
end
