defmodule Philomena.Analyzers.Webp do
  def analyze(file) do
    stats = stats(file)

    %{
      extension: "webp",
      mime_type: "image/webp",
      animated?: false,
      duration: stats.duration,
      dimensions: stats.dimensions
    }
  end

  defp stats(file) do
    ffprobe_opts = [
      "-v",
      "error",
      "-select_streams",
      "v",
      "-show_entries",
      "stream=width,height",
      "-of",
      "json",
      file
    ]

    with {iodata, 0} <- System.cmd("ffprobe", ffprobe_opts),
         {:ok, %{"streams" => [%{"width" => width, "height" => height}]}} <- Jason.decode(iodata) do
      %{dimensions: {width, height}, duration: 1 / 25}
    else
      _ ->
        %{dimensions: {0, 0}, duration: 0.0}
    end
  end
end
