defmodule Philomena.SearchSyntaxCase do
  @moduledoc """
  This module defines the setup for testing the Philomena Search Syntax parser.
  """

  alias PhilomenaQuery.Parse.Parser
  alias Philomena.Labeled
  import AssertValue

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Philomena.Labeled
      import Philomena.SearchSyntaxCase, only: [assert_search_syntax: 1]
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Philomena.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  # Context combinations multimap. The number of keys in this map should be kept
  # small, because the test calculates a multi-cartesian product of values
  # between the keys of this map.
  @type contexts_schema :: %{String.t() => [Labeled.t(any()) | any()]}

  @type search_syntax_test :: %{
          # The so-called "system under test". This function accepts a Philomena
          # Search Syntax string, a context and returns the compiled OpenSearch
          # query.
          compile: (String.t(), keyword([any()]) -> Parser.result()),

          # Defines the combinations of contexts to test with.
          contexts: contexts_schema(),

          # Path to the file where to store the snapshot of the test results.
          snapshot: String.t(),

          # The test cases with input Philomena Search Syntax strings arbitrarily grouped for
          # readability.
          test_cases: keyword([String.t()])
        }

  @spec assert_search_syntax(search_syntax_test()) :: :ok
  def assert_search_syntax(test) do
    actual =
      test.test_cases
      |> map_values(fn inputs ->
        inputs
        |> Enum.map(&compile_input(test, &1))
        |> List.flatten()
      end)
      |> Jason.OrderedObject.new()
      |> Jason.encode!(pretty: true)

    # Elixir's `System.cmd` API doesn't support passing custom payload via stdin
    # for a command. As a simple workaround we use a bash wrapper that translates
    # a CLI parameter into the stdin for `prettier`. An alternative way to do
    # that could be with the Port API, but bash solution is a bit simpler:
    # hexdocs.pm/elixir/1.18.3/Port.html#module-example
    {actual, 0} =
      System.cmd(
        "bash",
        [
          "-c",
          "echo \"$1\" | npx prettier --stdin-filepath \"$2\" --parser json",
          "--",
          actual,
          test.snapshot
        ]
      )

    assert_value(actual == File.read!(test.snapshot))
    :ok
  end

  @spec compile_input(search_syntax_test(), String.t()) :: [map()]
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

  # Reduces all the combinations of contexts that produce the same output. For
  # example the sequence like this:
  # ```ex
  # [%{ a: "a1", b: "bar1" }, %{ a: "a2", b: "bar2" }]
  # ```
  # will be reduced to:
  # ```ex
  # [%{ a: ["a1", "a2"] }]
  # ```
  # only if `bar1` and `bar2` cover the set of all possible values for `b`, and
  # `a1` and `a2` don't cover the set of all possible values for `a`.
  #
  # In other words the value of `b` doesn't influence the output at all, and
  # thus can be omitted in the normalized contexts list, and the values of `a`
  # are just collected into a list in a single map instead of being several maps
  # with a single value in each of them.
  @spec normalize_contexts(contexts_schema(), [map()]) :: [map()]
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
        values = Map.keys(groups) |> Enum.sort()

        normalize_contexts(schema, other)
        |> Enum.map(&Map.merge(&1, %{key => values}))

      _ ->
        normalize_contexts(schema, contexts)
    end
  end
end
