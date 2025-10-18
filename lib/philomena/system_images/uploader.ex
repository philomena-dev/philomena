defmodule Philomena.SystemImages.Uploader do
  @moduledoc """
  Upload and processing callback logic for system images.
  """

  alias Philomena.SystemImages.SystemImage
  alias Philomena.SystemImages.FaviconGenerator
  alias PhilomenaMedia.Uploader

  def upload_system_image(file, "favicon.svg") do
    path = Path.join(system_file_root(), "favicon.svg")

    Uploader.persist_file(path, file)
    generate_favicon_ico(file)
  end

  def upload_system_image(file, image_name) do
    path = Path.join(system_file_root(), image_name)

    Uploader.persist_file(path, file)
  end

  defp generate_favicon_ico(file) do
    outfile = Briefly.create!(extname: ".ico")

    Remote.cmd("magick", ["-density", "256x256", "-background", "transparent", "-define", "icon:auto-resize=\"16,32,48,64,128\"", file, outfile])
    upload_system_image(outfile, "favicon.ico")
  end

  defp system_file_root,
    do: Application.fetch_env!(:philomena, :system_file_root)

  defp system_url_root,
    do: Application.fetch_env!(:philomena, :system_url_root)
end
