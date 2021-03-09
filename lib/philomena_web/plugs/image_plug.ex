defmodule PhilomenaWeb.ImagePlug do
  alias PhilomenaWeb.ImageUpdater
  def init([]), do: []
  
  def call(conn, _opts) do
	record_impression(conn.assigns.image)
	conn
  end
  
  defp record_impression(nil), do: nil
  
  defp record_impression(image) do
    ImageUpdater.cast(image.id)
    image
  end
end