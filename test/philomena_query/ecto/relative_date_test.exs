defmodule PhilomenaQuery.Ecto.RelativeDateTest do
  use ExUnit.Case, async: true

  alias PhilomenaQuery.Ecto.RelativeDate

  describe "cast/1" do
    test "parses absolute and relative dates" do
      assert RelativeDate.cast("2024-01-01T00:00:00Z") == {:ok, ~U[2024-01-01 00:00:00Z]}
      assert {:ok, %DateTime{}} = RelativeDate.cast("three days from now")
    end

    test "rejects text that is no date with a message" do
      assert RelativeDate.cast("next tuesday") ==
               {:error, [message: "is not a valid relative or absolute date and time"]}
    end

    test "keeps a datetime and rejects submitted values that are not text" do
      assert RelativeDate.cast(~U[2024-01-01 00:00:00Z]) == {:ok, ~U[2024-01-01 00:00:00Z]}
      assert RelativeDate.cast(%{"x" => "1"}) == :error
      assert RelativeDate.cast(["2024"]) == :error
    end
  end

  test "loads a database timestamp as a UTC datetime without microseconds" do
    assert RelativeDate.load(~N[2024-01-01 00:00:00.123456]) == {:ok, ~U[2024-01-01 00:00:00Z]}
    assert RelativeDate.dump(~U[2024-01-01 00:00:00Z]) == {:ok, ~U[2024-01-01 00:00:00Z]}
  end
end
