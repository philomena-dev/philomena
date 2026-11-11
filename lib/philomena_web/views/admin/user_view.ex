defmodule PhilomenaWeb.Admin.UserView do
  use PhilomenaWeb, :view

  def scope(conn) do
    []
    |> scope(conn, "uq", :uq)
    |> scope(conn, "sf", :sf)
    |> scope(conn, "sd", :sd)
  end

  defp scope(list, conn, key, key_atom) do
    case conn.params[key] do
      nil -> list
      "" -> list
      val -> [{key_atom, val} | list]
    end
  end

  def description("moderator", "Image"), do: "Manage images"
  def description("moderator", "DuplicateReport"), do: "Manage duplicates"
  def description("moderator", "Comment"), do: "Manage comments"
  def description("moderator", "ArtistLink"), do: "Manage artist links"
  def description("moderator", "Topic"), do: "Moderate forums"

  def description("moderator", "Tag"), do: "Manage tag details"
  def description("admin", "Tag"), do: "Alias tags"
  def description("batch_update", "Tag"), do: "Update tags in batches"

  def description("moderator", "User"), do: "Manage users and wipe votes"
  def description("admin", "Role"), do: "Manage permissions"
  def description("admin", "SiteNotice"), do: "Manage site notices"
  def description("admin", "Badge"), do: "Manage badges"
  def description("admin", "Advert"), do: "Manage ads"
  def description("admin", "StaticPage"), do: "Manage static pages"
  def description("admin", "Image"), do: "Hard-delete images"

  def description(_name, _resource_type), do: "(unknown permission)"

  def filtered_roles(permission_set, roles) do
    roles
    |> Enum.filter(&Enum.member?(permission_set, [&1.name, &1.resource_type]))
    |> Enum.map(&{description(&1.name, &1.resource_type), &1.id})
  end

  def role_ids(user), do: Enum.map(user.roles, & &1.id)

  def general_permissions do
    [
      ["batch_update", "Tag"]
    ]
  end

  def assistant_permissions do
    [
      ["moderator", "Image"],
      ["moderator", "DuplicateReport"],
      ["moderator", "Comment"],
      ["moderator", "Tag"],
      ["moderator", "ArtistLink"],
      ["moderator", "Topic"]
    ]
  end

  def moderator_permissions do
    [
      ["moderator", "User"],
      ["admin", "Tag"],
      ["admin", "Role"],
      ["admin", "SiteNotice"],
      ["admin", "Badge"],
      ["admin", "Advert"],
      ["admin", "StaticPage"],
      ["admin", "Image"]
    ]
  end
end
