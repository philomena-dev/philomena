defmodule Mix.Tasks.ConvertEctoMacros do
  use Mix.Task

  @impl Mix.Task
  def run(_) do
    module_map = prepare_code()

    Path.wildcard("test/**/*.ex*")
    |> Enum.concat(Path.wildcard("lib/**/*.ex*"))
    |> Enum.sort()
    |> Enum.filter(&(&1 |> File.read!() |> String.contains?("import Ecto.Query")))
    |> Enum.each(&format_file(&1, module_map))

    :ok
  end

  defp prepare_code do
    Enum.reduce(:code.all_available(), %{}, fn {_, beam_file, _}, acc ->
      case :beam_lib.chunks(beam_file, [:compile_info]) do
        {:ok, {module, [{_, [{_, _}, {_, _}, {:source, source}]}]}} ->
          source = to_string(source)

          Map.update(acc, source, [module], &[module|&1])

        _ ->
          acc
      end
    end)
  end

  defp format_file(filename, module_map) do
    fullname = Path.expand(filename)
    modules = Map.get(module_map, fullname, [])

    Mix.shell().info("#{filename}")

    Enum.each(modules, fn module ->
      lines = extract_lines(module)
      Mix.shell().info("  #{inspect(module)}: #{inspect(lines)}")
    end)
  end

  defp extract_lines(module) do
    which = :code.which(module)
    {:ok, {_, [{_, {_, ast}}]}} = :beam_lib.chunks(which, [:abstract_code])

    ast
    |> traverse()
    |> Map.new()
  end

  defp traverse(term) when is_list(term) do
    Enum.flat_map(term, &traverse/1)
  end

  defp traverse({:atom, line, name}) do
    if String.starts_with?(to_string(name), "Elixir.Ecto.Query.") do
      [{line, true}]
    else
      []
    end
  end

  defp traverse(term) when is_tuple(term) and term != {} do
    size = tuple_size(term)
    traverse(for i <- 0..(size - 1), do: elem(term, i))
  end

  defp traverse(_term), do: []
end
