defmodule Philomena.Processors.Webp do
  alias Philomena.Intensities

  def versions(sizes) do
    Enum.map(sizes, fn {name, _} -> "#{name}.webp" end)
  end

  def process(_analysis, file, versions) do
    stripped = strip(file)
    preview = preview(file)

    {:ok, intensities} = Intensities.file(preview)

    scaled = Enum.flat_map(versions, &scale(stripped, &1))

    %{
      replace_original: stripped,
      intensities: intensities,
      thumbnails: scaled
    }
  end

  def post_process(_analysis, _file), do: %{}

  def intensities(_analysis, file) do
    {:ok, intensities} = Intensities.file(file)
    intensities
  end

  defp preview(file) do
    preview = Briefly.create!(extname: ".png")

    {_output, 0} =
      System.cmd("convert", [
        file,
        "-auto-orient",
        "-strip",
        preview
      ])

    preview
  end

  defp strip(file) do
    stripped = Briefly.create!(extname: ".webp")

    {_output, 0} =
      System.cmd("convert", [
        file,
        "-auto-orient",
        "-strip",
        stripped
      ])

    stripped
  end

  defp scale(file, {thumb_name, {width, height}}) do
    scaled = Briefly.create!(extname: ".webp")
    scale_filter = "scale=w=#{width}:h=#{height}:force_original_aspect_ratio=decrease"

    {_output, 0} =
      System.cmd("ffmpeg", [
        "-loglevel",
        "0",
        "-y",
        "-i",
        file,
        "-vf",
        scale_filter,
        "-q:v",
        "1",
        scaled
      ])

    [{:copy, scaled, "#{thumb_name}.webp"}]
  end
end
