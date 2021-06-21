defmodule PhilomenaWeb.SettingView do
  use PhilomenaWeb, :view

  def theme_options(conn) do
    [
      [
        key: "#{booru_name()} Default",
        value: "default",
        data: [theme_path: Routes.static_path(conn, "/css/default.css")]
      ],
      [
        key: "Philomena Dark",
        value: "dark",
        data: [theme_path: Routes.static_path(conn, "/css/dark.css")]
      ],
      [
        key: "Philomena Red",
        value: "red",
        data: [theme_path: Routes.static_path(conn, "/css/red.css")]
      ],
      [
        key: "Philomena Light",
        value: "olddefault",
        data: [theme_path: Routes.static_path(conn, "/css/olddefault.css")]
      ],
      [
        key: "Ponerpics Default",
        value: "ponerpics-default",
        data: [theme_path: Routes.static_path(conn, "/css/ponerpics-default.css")]
      ],
      [
        key: "Manebooru Fuchsia",
        value: "manebooru-fuchsia",
        data: [theme_path: Routes.static_path(conn, "/css/manebooru-fuchsia.css")]
      ],
      [
        key: "Manebooru Green",
        value: "manebooru-green",
        data: [theme_path: Routes.static_path(conn, "/css/manebooru-green.css")]
      ],
      [
        key: "Manebooru Orange",
        value: "manebooru-orange",
        data: [theme_path: Routes.static_path(conn, "/css/manebooru-orange.css")]
      ],
      [
        key: "Twibooru Default",
        value: "twibooru-default",
        data: [theme_path: Routes.static_path(conn, "/css/twibooru-default.css")]
      ],
      [
        key: "Furbooru Default",
        value: "furbooru-default",
        data: [theme_path: Routes.static_path(conn, "/css/furbooru-default.css")]
      ],
      [
        key: "Bronyhub Default",
        value: "bronyhub-default",
        data: [theme_path: Routes.static_path(conn, "/css/bronyhub-default.css")]
      ]
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
