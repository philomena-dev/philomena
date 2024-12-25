defmodule PhilomenaMedia.Analyzers.Webm do
  @moduledoc false

  alias PhilomenaMedia.Analyzers.Analyzer
  alias PhilomenaMedia.Analyzers.Result
  alias PhilomenaMedia.Remote

  @behaviour Analyzer

  @spec analyze(Path.t()) :: Result.t()
  def analyze(file) do
    stats = stats(file)

    %Result{
      extension: "webm",
      mime_type: "video/webm",
      animated?: stats.animated?,
      duration: stats.duration,
      dimensions: stats.dimensions
    }
  end

  defp stats(file) do
    case Remote.cmd("mediastat", [file]) do
      {output, 0} ->
        [_size, frames, width, height, num, den] =
          output
          |> String.trim()
          |> String.split(" ")
          |> Enum.map(&String.to_integer/1)

        %{animated?: frames > 1, dimensions: {width, height}, duration: num / den}

      _ ->
        %{animated?: false, dimensions: {0, 0}, duration: 0.0}
    end
  end
end
