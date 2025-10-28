defmodule PhilomenaWeb.TagChangeView do
  alias Philomena.Slug
  alias Philomena.Tags.Tag

  use PhilomenaWeb, :view

  def scope(conn) do
    []
    |> scope(conn, "tcq", :tcq)
    |> scope(conn, "sf", :sf)
    |> scope(conn, "sd", :sd)
    |> scope(conn, "resource_type", :resource_type)
    |> scope(conn, "resource_id", :resource_id)
  end

  defp scope(list, conn, key, key_atom) do
    case conn.params[key] do
      nil -> list
      "" -> list
      val -> [{key_atom, val} | list]
    end
  end

  def staff?(tag_change),
    do:
      not is_nil(tag_change.user) and not Philomena.Attribution.anonymous?(tag_change) and
        tag_change.user.role != "user" and not tag_change.user.hide_default_role

  def user_block_class(tag_change) do
    if staff?(tag_change) do
      "tag__change--staff"
    else
      nil
    end
  end

  def reverts_tag_changes?(conn),
    do: can?(conn, :revert, Philomena.TagChanges.TagChange)

  def non_retained_tags(%{image: image, tags: tags}) do
    tags
    |> Enum.filter(fn tct ->
      tct.added != Enum.any?(image.tags, &(&1.id == tct.tag.id))
    end)
  end

  def tag_not_retained(non_retained, tag) do
    Enum.any?(non_retained, &(&1.tag_id == tag.id))
  end

  def non_retained_class(non_retained, tag) do
    if tag_not_retained(non_retained, tag) do
      "tag__change--not-retained"
    else
      ""
    end
  end

  def split_tags(tag_change) do
    {added_tags, removed_tags} = Enum.split_with(tag_change.tags, & &1.added)

    {
      added_tags |> Enum.map(& &1.tag) |> Tag.display_order(),
      removed_tags |> Enum.map(& &1.tag) |> Tag.display_order()
    }
  end

  def link_to_resource("image", id), do: link("image ##{id}", to: ~p"/images/#{id}")
  def link_to_resource("ip", ip), do: link(ip, to: ~p"/ip_profiles/#{ip}")
  def link_to_resource("fingerprint", fp), do: link(fp, to: ~p"/fingerprint_profiles/#{fp}")
  def link_to_resource("user", name), do: link(name, to: ~p"/profiles/#{Slug.slug(name)}")
  def link_to_resource("tag", name), do: link("tag '#{name}'", to: ~p"/tags/#{Slug.slug(name)}")
  def link_to_resource(_, _), do: ""
end
