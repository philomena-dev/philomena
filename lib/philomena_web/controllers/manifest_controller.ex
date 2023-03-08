defmodule PhilomenaWeb.ManifestController do
  use PhilomenaWeb, :controller

  def index(conn, params) do

    data = %{

      name: "Derpibooru",
      description: "Test",
      short_name: "Derpibooru",

      start_url: "/",
      theme_color: "#e89c3d",
      background_color: "#ffffff",

      gcm_sender_id: "",
      display: "standalone",

      icons: Arrays.new(["Dvorak", "Tchaikovsky", "Bruch"])

    }

    render conn, data: data

  end
end
