defmodule PhilomenaWeb.SettingView do
  use PhilomenaWeb, :view

  def theme_options(conn) do
    [
      [
        key: "Blue (default)",
        value: "dark-blue",
        data: [theme_path: Routes.static_path(conn, "/css/dark-blue.css")]
      ],
      [
        key: "Red",
        value: "dark-red",
        data: [theme_path: Routes.static_path(conn, "/css/dark-red.css")]
      ],
      [
        key: "Green",
        value: "dark-green",
        data: [theme_path: Routes.static_path(conn, "/css/dark-green.css")]
      ],
      [
        key: "Purple",
        value: "dark-purple",
        data: [theme_path: Routes.static_path(conn, "/css/dark-purple.css")]
      ],
      [
        key: "Pink",
        value: "dark-pink",
        data: [theme_path: Routes.static_path(conn, "/css/dark-pink.css")]
      ],
      [
        key: "Yellow",
        value: "dark-yellow",
        data: [theme_path: Routes.static_path(conn, "/css/dark-yellow.css")]
      ],
      [
        key: "Cyan",
        value: "dark-cyan",
        data: [theme_path: Routes.static_path(conn, "/css/dark-cyan.css")]
      ],
      [
        key: "Grey",
        value: "dark-grey",
        data: [theme_path: Routes.static_path(conn, "/css/dark-grey.css")]
      ]
    ]
  end

  def light_theme_options(conn) do
    [
      [
        key: "Blue (default)",
        value: "light-blue",
        data: [theme_path: Routes.static_path(conn, "/css/light-blue.css")]
      ],
      [
        key: "Red",
        value: "light-red",
        data: [theme_path: Routes.static_path(conn, "/css/light-red.css")]
      ],
      [
        key: "Green",
        value: "light-green",
        data: [theme_path: Routes.static_path(conn, "/css/light-green.css")]
      ],
      [
        key: "Purple",
        value: "light-purple",
        data: [theme_path: Routes.static_path(conn, "/css/light-purple.css")]
      ],
      [
        key: "Pink",
        value: "light-pink",
        data: [theme_path: Routes.static_path(conn, "/css/light-pink.css")]
      ],
      [
        key: "Yellow",
        value: "light-yellow",
        data: [theme_path: Routes.static_path(conn, "/css/light-yellow.css")]
      ],
      [
        key: "Cyan",
        value: "light-cyan",
        data: [theme_path: Routes.static_path(conn, "/css/light-cyan.css")]
      ],
      [
        key: "Grey",
        value: "light-grey",
        data: [theme_path: Routes.static_path(conn, "/css/light-grey.css")]
      ]
    ]
  end

  def scale_options do
    [
      [key: "Load full images on image pages", value: "false"],
      [key: "Load full images on image pages, sized to fit the page", value: "partscaled"],
      [key: "Scale large images down before downloading", value: "true"]
    ]
  end

  def local_tab_class(conn) do
    case conn.assigns.current_user do
      nil -> ""
      _user -> "hidden"
    end
  end

  def staff?(%{role: role}), do: role != "user"
  def staff?(_), do: false
end
