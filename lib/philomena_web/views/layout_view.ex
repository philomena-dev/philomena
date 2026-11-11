defmodule PhilomenaWeb.LayoutView do
  use PhilomenaWeb, :view

  import PhilomenaWeb.Config
  import PhilomenaWeb.FrontendAssets
  alias PhilomenaWeb.ImageView
  alias Philomena.Config
  alias Philomena.Users.User
  alias Philomena.Users.Settings
  alias Plug.Conn

  def layout_class(conn) do
    conn.assigns[:layout_class] || "page-narrow"
  end

  @doc "Centers the page, unless the signed-in user turned that off."
  def centering_class(%{settings: %{use_centered_layout: false}}), do: nil
  def centering_class(_user), do: "page-centered"

  def philomena_version, do: Application.spec(:philomena, :vsn)

  def render_time(conn) do
    (Time.diff(Time.utc_now(), conn.assigns[:start_time], :microsecond) / 1000.0)
    |> Float.round(3)
    |> Float.to_string()
  end

  def hide_version do
    Application.get_env(:philomena, :hide_version) == "true"
  end

  def cdn_host do
    Application.get_env(:philomena, :cdn_host)
  end

  def generator_name do
    if hide_version() do
      "Philomena"
    else
      "Philomena v#{philomena_version()}"
    end
  end

  defp ignored_tag_list(nil), do: []
  defp ignored_tag_list([]), do: []
  defp ignored_tag_list([{tag, _body, _dnp_entries}]), do: [tag.id]
  defp ignored_tag_list(tags), do: Enum.map(tags, & &1.id)

  def clientside_data(conn) do
    conn = Conn.fetch_cookies(conn)

    extra = Map.get(conn.assigns, :clientside_data, [])
    interactions = Map.get(conn.assigns, :interactions, [])
    user = conn.assigns.current_user
    filter = conn.assigns.current_filter

    data = [
      filter_id: filter.id,
      hidden_tag_list: JSON.encode!(filter.hidden_tag_ids),
      hidden_filter: PhilomenaQuery.Parse.String.normalize(filter.hidden_complex_str || ""),
      spoilered_tag_list: JSON.encode!(filter.spoilered_tag_ids),
      spoilered_filter: PhilomenaQuery.Parse.String.normalize(filter.spoilered_complex_str || ""),
      user_id: if(user, do: user.id, else: nil),
      user_name: if(user, do: user.name, else: nil),
      user_slug: if(user, do: user.slug, else: nil),
      user_role: if(user, do: user.role, else: nil),
      user_is_signed_in: if(user, do: "true", else: "false"),
      user_can_edit_filter: if(user, do: filter.user_id == user.id, else: "false") |> to_string(),
      spoiler_type: if(user, do: user.settings.spoiler_type, else: "static"),
      watched_tag_list: JSON.encode!(if(user, do: user.watched_tag_ids, else: [])),
      fancy_tag_edit:
        if(user, do: user.settings.fancy_tag_field_on_edit, else: "true") |> to_string(),
      fancy_tag_upload:
        if(user, do: user.settings.fancy_tag_field_on_upload, else: "true") |> to_string(),
      interactions: JSON.encode!(interactions),
      ignored_tag_list: JSON.encode!(ignored_tag_list(conn.assigns[:tags])),
      hide_staff_tools: conn.cookies["hide_staff_tools"] |> to_string()
    ]

    data = Keyword.merge(data, extra)

    content_tag(:div, "", class: "js-datastore", data: data)
  end

  def footer_data do
    Config.get(:footer)
  end

  @doc """
  The mode (`dark` or `light`) of a signed-in user's theme, for `<html data-theme>`. Anonymous users have none:
  their pages follow the system's color scheme.
  """
  def theme_mode(nil), do: nil
  def theme_mode(user), do: user |> user_theme() |> Settings.split_theme() |> elem(0)

  def user_stylesheet_path(user), do: user |> user_theme() |> theme_stylesheet_path()

  @doc "The stylesheet of a theme such as `dark-purple`: the one of its color, for both modes."
  def theme_stylesheet_path(theme) do
    {_name, color} = Settings.split_theme(theme)
    static_path(PhilomenaWeb.Endpoint, "/css/#{color}.css")
  end

  defp user_theme(%{settings: %{theme: theme}}), do: theme
  defp user_theme(_user), do: %Settings{}.theme

  def hide_staff_tools_attribute(conn),
    do: if(conn.cookies["hide_staff_tools"] == "true", do: "true", else: "false")

  def artist_tags(tags),
    do: Enum.filter(tags, &(&1.namespace == "artist"))

  def opengraph?(conn),
    do:
      !is_nil(conn.assigns[:image]) and conn.assigns.image.__meta__.state == :loaded and
        is_list(conn.assigns.image.tags)

  @doc """
  The sections of the site that the secondary bar and the burger menu link to, each with the pages under it.
  """
  def site_sections(conn) do
    forums = Enum.map(conn.assigns.forums, &%{label: &1.name, path: ~p"/forums/#{&1}"})

    [
      %{
        icon: "fa fa-images",
        label: "Images",
        path: ~p"/images",
        pages: [%{icon: "fa fa-random", label: "Random", path: ~p"/images/random"}]
      },
      %{
        icon: "fa fa-bolt",
        label: "Activity",
        path: ~p"/activity",
        pages: [%{icon: "fa fa-comments", label: "Comments", path: ~p"/comments"}]
      },
      %{
        icon: "fas fa-pen-square",
        label: "Forums",
        path: ~p"/forums",
        pages: forums ++ [%{icon: "fa fa-search", label: "Post Search", path: ~p"/posts"}]
      },
      %{
        icon: "fa fa-tag",
        label: "Tags",
        path: ~p"/tags",
        pages: [%{icon: "fa fa-tags", label: "Tag Changes", path: ~p"/tag_changes"}]
      },
      %{
        icon: "fa fa-podcast",
        label: "Live",
        path: ~p"/channels",
        pages: [],
        count: conn.assigns.live_channels
      },
      %{icon: "fa fa-image", label: "Galleries", path: ~p"/galleries", pages: []},
      %{icon: "fa fa-address-card", label: "Commissions", path: ~p"/commissions", pages: []}
    ]
  end

  @doc """
  The selects that switch a signed-in user's current filter and spoiler type, which the header and the
  burger menu render: an optional `name` replaces the parameter the select submits, an optional
  `header_class` hides it in the header.
  """
  def quick_selects(assigns) do
    [
      %{
        key: "filter",
        label: "Filter",
        changeset: assigns.user_changeset,
        action: ~p"/filters/current",
        field: :current_filter_id,
        options: assigns.available_filters,
        name: "id"
      },
      %{
        key: "spoiler",
        label: "Spoilers",
        changeset: assigns.spoiler_changeset,
        action: ~p"/filters/spoiler_type",
        field: :spoiler_type,
        options: assigns.spoiler_types,
        header_class: "hidden-below-xl"
      }
    ]
  end

  @doc "The pages of a signed-in user's menu, from the profile to logging out."
  def user_links(user) do
    [
      %{icon: "fa fa-user-circle", label: user.name, path: ~p"/profiles/#{user}"},
      %{icon: "fa fa-eye", label: "Watched", path: ~p"/search?q=my:watched"},
      %{icon: "fa fa-star", label: "Faves", path: ~p"/search?q=my:faves"},
      %{icon: "fa fa-arrow-up", label: "Upvotes", path: ~p"/search?q=my:upvotes"},
      %{
        icon: "fa fa-image",
        label: "Galleries",
        path: ~p"/galleries?#{[gallery: [creator: user.name]]}"
      },
      %{icon: "fa fa-upload", label: "Uploads", path: ~p"/search?q=my:uploads"},
      %{icon: "fa fa-comments", label: "Comments", path: ~p"/comments?cq=my:comments"},
      %{icon: "fas fa-pen-square", label: "Posts", path: ~p"/posts?pq=my:posts"},
      %{icon: "fa fa-link", label: "Links", path: ~p"/profiles/#{user}/artist_links"},
      %{icon: "fa fa-cogs", label: "Settings", path: ~p"/settings/edit"},
      %{icon: "fa fa-envelope", label: "Messages", path: ~p"/conversations"},
      %{icon: "fa fa-user", label: "Account", path: ~p"/registrations/edit"},
      %{icon: "fa fa-sign-out-alt", label: "Logout", path: ~p"/sessions", method: "delete"}
    ]
  end

  @doc """
  The administration pages the signed-in staff member may manage; every staff role may at least read the mod notes.
  """
  def admin_links(conn) do
    for {allowed?, icon, label, path} <- [
          {manages_site_notices?(conn), "fa fa-info-circle", "Site Notices",
           ~p"/admin/site_notices"},
          {manages_users?(conn), "fa fa-users", "Users", ~p"/admin/users"},
          {manages_forums?(conn), "fa fa-paragraph", "Forums", ~p"/admin/forums"},
          {manages_ads?(conn), "fa fa-shopping-bag", "Adverts", ~p"/admin/adverts"},
          {manages_badges?(conn), "fa fa-trophy", "Badges", ~p"/admin/badges"},
          {manages_static_pages?(conn), "fa fa-sticky-note", "Pages", ~p"/pages"},
          {manages_mod_notes?(conn), "fa fa-clipboard", "Mod Notes", ~p"/admin/mod_notes"},
          {can_see_moderation_log?(conn), "fa fa-list-alt", "Mod Logs", ~p"/moderation_logs"}
        ],
        allowed?,
        do: %{icon: icon, label: label, path: path}
  end

  @doc "The ban lists, for staff who may ban."
  def ban_links(conn) do
    if manages_bans?(conn) do
      [
        %{icon: "fa fa-user", label: "User Bans", path: ~p"/admin/user_bans"},
        %{icon: "fab fa-internet-explorer", label: "IP Bans", path: ~p"/admin/subnet_bans"},
        %{icon: "fa fa-desktop", label: "FP Bans", path: ~p"/admin/fingerprint_bans"}
      ]
    else
      []
    end
  end

  @doc """
  Whether `path` is the page being shown or a section it belongs to. Links with a query, which are searches,
  never are.
  """
  def current_page?(conn, path) do
    not String.contains?(path, "?") and
      (conn.request_path == path or String.starts_with?(conn.request_path, path <> "/"))
  end

  def staff?(conn) do
    case conn.assigns.current_user do
      %User{role: role} -> role != "user"
      _ -> false
    end
  end

  def hides_images?(conn),
    do: can?(conn, :hide, %Philomena.Images.Image{})

  def manages_site_notices?(conn),
    do: can?(conn, :index, Philomena.SiteNotices.SiteNotice)

  def manages_tags?(conn),
    do: can?(conn, :edit, %Philomena.Tags.Tag{})

  def manages_users?(conn),
    do: can?(conn, :index, Philomena.Users.User)

  def manages_forums?(conn),
    do: can?(conn, :edit, Philomena.Forums.Forum)

  def manages_ads?(conn),
    do: can?(conn, :index, Philomena.Adverts.Advert)

  def manages_badges?(conn),
    do: can?(conn, :index, Philomena.Badges.Badge)

  def manages_static_pages?(conn),
    do: can?(conn, :edit, %Philomena.StaticPages.StaticPage{})

  def manages_mod_notes?(conn),
    do: can?(conn, :index, Philomena.ModNotes.ModNote)

  def manages_bans?(conn),
    do: can?(conn, :create, Philomena.Bans.User)

  def can_see_moderation_log?(conn),
    do: can?(conn, :index, Philomena.ModerationLogs.ModerationLog)

  def viewport_meta_tag(conn) do
    ua = get_user_agent(conn)

    if String.contains?(ua, ["Mobile", "webOS"]) do
      tag(:meta, name: "viewport", content: "width=device-width, initial-scale=1")
    else
      tag(:meta, name: "viewport", content: "width=1024, initial-scale=1")
    end
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua] -> ua
      _ -> ""
    end
  end
end
