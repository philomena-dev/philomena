defmodule PhilomenaWeb.ManifestView do
  use PhilomenaWeb, :view

  def render("index.json", %{
    data: data
  }) do
    %{
      name: data.name,
      description: data.description,
      short_name: data.short_name,
      start_url: data.start_url,
      theme_color: data.theme_color,
      background_color: data.background_color,
      gcm_sender_id: data.gcm_sender_id,
      display: data.display,
      icons: data.icons
    }
  end


end
