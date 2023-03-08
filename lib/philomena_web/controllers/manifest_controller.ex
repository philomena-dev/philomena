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

      icons: [
        %{
            src: "/icon/16.png",
            sizes: "16x16",
            type: "image/png"
        },
        %{
            src: "/icon/24.png",
            sizes: "24x24",
            type: "image/png"
        },
        %{
            src: "/icon/32.png",
            sizes: "32x32",
            type: "image/png"
        },
        %{
            src: "/icon/48.png",
            sizes: "48x48",
            type: "image/png"
        },
        %{
            src: "/icon/64.png",
            sizes: "64x64",
            type: "image/png"
        },
        %{
            src: "/icon/72.png",
            sizes: "72x72",
            type: "image/png"
        },
        %{
            src: "/icon/80.png",
            sizes: "80x80",
            type: "image/png"
        },
        %{
            src: "/icon/96.png",
            sizes: "96x96",
            type: "image/png"
        },
        %{
            src: "/icon/128.png",
            sizes: "128x128",
            type: "image/png"
        },
        %{
            src: "/icon/256.png",
            sizes: "256x256",
            type: "image/png"
        }
      ]

    }

    render conn, data: data

  end
end
