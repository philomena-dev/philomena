defmodule Philomena.QueryCase do
  @moduledoc """
  This module defines the setup for testing the PhiQL (Philomena Query
  Language) parsing.
  """

  alias PhilomenaQuery.Parse.Parser
  alias Philomena.Labeled
  import AssertValue

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Philomena.Labeled
      alias Philomena.QueryCase
    end
  end

  # Context combinations multimap. The number of keys in this map should be kept
  # small, because the test calculates a multi-cartesian product of values
  # between the keys of this map.
  @type contexts_schema :: %{String.t() => [Labeled.t(any()) | any()]}

  @type phiql_test :: %{
          # The so-called "system under test". This function accepts a PhiQL
          # string, a context and returns the compiled OpenSearch query.
          compile: (String.t(), keyword([any()]) -> Parser.result()),

          # Defines the combinations of contexts to test with.
          contexts: contexts_schema(),

          # Path to the file where to store the snapshot of the test results.
          snapshot: String.t(),

          # The test cases with input PhiQL strings arbitrarily grouped for
          # readability.
          test_cases: keyword([String.t()])
        }

  @spec assert_phiql(phiql_test()) :: :ok
  def assert_phiql(test) do
    actual =
      test.test_cases
      |> map_values(fn inputs ->
        inputs
        |> Enum.map(&compile_input(test, &1))
        |> List.flatten()
      end)
      |> Jason.OrderedObject.new()
      |> Jason.encode!(pretty: true)

    assert_value(actual == File.read!(test.snapshot))
  end

  @spec compile_input(phiql_test(), String.t()) :: [map()]
  defp compile_input(test, input) do
    test.contexts
    |> multimap_cartesian_product()
    |> Enum.group_by(fn ctx ->
      ctx = map_values(ctx, &Labeled.prefer_value/1)

      case test.compile.(input, ctx) do
        {:ok, output} -> output
        {:error, error} -> "Error: #{error}"
      end
    end)
    |> Enum.map(fn {output, contexts} ->
      contexts =
        contexts
        |> Enum.map(fn ctx -> map_values(ctx, &Labeled.prefer_label/1) |> Map.new() end)

      contexts =
        case normalize_contexts(test.contexts, contexts) do
          [context] when map_size(context) == 0 -> []
          contexts -> [contexts: contexts]
        end

      Jason.OrderedObject.new(contexts ++ [philomena: input, opensearch: output])
    end)
  end

  @spec map_values([{k, v}], (v -> new_v)) :: [{k, new_v}]
        when k: any(), v: any(), new_v: any()
  defp map_values(key_values, map_value) do
    Enum.map(key_values, fn {key, value} -> {key, map_value.(value)} end)
  end

  defp multimap_cartesian_product(map) when map_size(map) == 0, do: [%{}]

  defp multimap_cartesian_product(map) do
    {key, values} = map |> Enum.at(0)

    rest = map |> Map.delete(key)

    for value <- values,
        rest <- multimap_cartesian_product(rest) do
      Map.put_new(rest, key, value)
    end
  end

  @spec normalize_contexts([contexts_schema()], [map()]) :: [map()]
  defp normalize_contexts(schema, contexts)

  defp normalize_contexts(schema, contexts) when map_size(schema) == 0 do
    contexts
  end

  defp normalize_contexts(schema, contexts) do
    {key, possible_values} = schema |> Enum.at(0)

    schema = schema |> Map.delete(key)

    groups =
      contexts
      |> Enum.group_by(
        fn ctx -> ctx[key] end,
        fn ctx -> Map.delete(ctx, key) end
      )

    groups
    |> Map.values()
    |> Enum.uniq()
    |> case do
      [other] when map_size(groups) == length(possible_values) ->
        normalize_contexts(schema, other)

      [other] ->
        values = Map.keys(groups)

        normalize_contexts(schema, other)
        |> Enum.map(&Map.merge(&1, %{key => values}))

      _ ->
        normalize_contexts(schema, contexts)
    end
  end
end
