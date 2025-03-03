defmodule PhilomenaWeb.SearchView do
  use PhilomenaWeb, :view

  def scope(conn), do: PhilomenaWeb.ImageScope.scope(conn)
  def hides_images?(conn), do: can?(conn, :hide, %Philomena.Images.Image{})

  def override_display(conn, [{tag, _description, dnp_entries}]) do
    Enum.any?(dnp_entries) or tag.images_count > 0 or
      (present?(tag.mod_notes) and can?(conn, :edit, tag))
  end

  def override_display(_, _), do: false
end
