defmodule PhilomenaWeb.ImagePlug do
  alias PhilomenaWeb.ImageUpdater
  alias Philomena.Images
  alias Plug.Conn
  
  def init([]), do: []
  
  def call(conn, _opts) do
	image = conn.assigns[:image]
  end
  
  defp record_impression(nil), do: nil
  
  defp record_impression(image) do
    ImageUpdater.cast(:image.id)
  
    image
  end
end