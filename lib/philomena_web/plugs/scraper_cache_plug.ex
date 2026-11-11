defmodule PhilomenaWeb.ScraperCachePlug do
  @spec init(any()) :: any()
  def init(opts) do
    opts
  end

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(%Plug.Conn{} = conn, _opts) do
    params =
      conn.params
      |> Map.put_new("image", %{})
      |> Map.put_new("scraper_cache", conn.params["url"])
      |> Map.put("distance", normalize_dist(conn.params))

    %Plug.Conn{conn | params: params}
  end

  defp normalize_dist(%{"distance" => distance}) when is_binary(distance) do
    case Float.parse("0" <> distance) do
      {distance, _rest} -> Float.to_string(distance)
      :error -> normalize_dist(nil)
    end
  end

  defp normalize_dist(_dist) do
    "0.25"
  end
end
