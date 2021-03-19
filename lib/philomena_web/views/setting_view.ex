defmodule PhilomenaWeb.SettingView do
  use PhilomenaWeb, :view

  def theme_options(conn) do
    [
      [
        key: "Ponybooru Default",
        value: "default",
        data: [theme_path: Routes.static_path(conn, "/css/default.css")]
      ],
      [key: "Philomena Dark", value: "dark", data: [theme_path: Routes.static_path(conn, "/css/dark.css")]],
      [key: "Philomena Red", value: "red", data: [theme_path: Routes.static_path(conn, "/css/red.css")]],
      [key: "Philomena Default", value: "olddefault", data: [theme_path: Routes.static_path(conn, "/css/olddefault.css")]],
	  [key: "Ponerpics Default", value: "ponerpicsdefault", data: [theme_path: Routes.static_path(conn, "/css/ponerpicsdefault.css")]],
	  [key: "Manebooru Default", value: "maneboorudefault", data: [theme_path: Routes.static_path(conn, "/css/maneboorudefault.css")]],
	  [key: "Manebooru Fuchsia", value: "maneboorufuchsia", data: [theme_path: Routes.static_path(conn, "/css/maneboorufuchsia.css")]],
	  [key: "Manebooru Green", value: "maneboorugreen", data: [theme_path: Routes.static_path(conn, "/css/maneboorugreen.css")]],
	  [key: "Manebooru Orange", value: "manebooruorange", data: [theme_path: Routes.static_path(conn, "/css/manebooruorange.css")]],
	  [key: "Twibooru Default", value: "twiboorudefault", data: [theme_path: Routes.static_path(conn, "/css/twiboorudefault.css")]],
	  [key: "Furbooru Default", value: "furboorudefault", data: [theme_path: Routes.static_path(conn, "/css/furboorudefault.css")]]
	  
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
