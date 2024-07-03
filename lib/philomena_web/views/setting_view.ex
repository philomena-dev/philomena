defmodule PhilomenaWeb.SettingView do
  use PhilomenaWeb, :view

  def themes do
    [
      Dark: "dark",
      Light: "light"
    ]
  end

  def theme_colors do
    [
      Red: "red",
      Orange: "orange",
      Yellow: "yellow",
      Green: "green",
      Blue: "blue",
      Purple: "purple",
      Cyan: "cyan",
      Pink: "pink",
      "Silver/Charcoal": "silver"
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
