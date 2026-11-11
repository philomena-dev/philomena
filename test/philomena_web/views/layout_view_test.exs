defmodule PhilomenaWeb.LayoutViewTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  alias Philomena.SiteNotices.SiteNotice
  alias Philomena.Users.{Settings, User}
  alias PhilomenaWeb.LayoutView

  defp staff_links(conn, user) do
    conn = viewer_conn(conn, user)

    Phoenix.View.render_to_string(
      LayoutView,
      "_header_staff_links.html",
      Map.put(conn.assigns, :conn, conn)
    )
  end

  defp tool_visibility(conn, user) do
    conn = viewer_conn(conn, user)

    %{
      hidden_images: LayoutView.hides_images?(conn),
      site_notices: LayoutView.manages_site_notices?(conn),
      tags: LayoutView.manages_tags?(conn),
      users: LayoutView.manages_users?(conn),
      forums: LayoutView.manages_forums?(conn),
      adverts: LayoutView.manages_ads?(conn),
      badges: LayoutView.manages_badges?(conn),
      static_pages: LayoutView.manages_static_pages?(conn),
      mod_notes: LayoutView.manages_mod_notes?(conn),
      bans: LayoutView.manages_bans?(conn),
      moderation_log: LayoutView.can_see_moderation_log?(conn)
    }
  end

  describe "staff tool visibility" do
    test "anonymous and regular viewers see no staff tools", %{conn: conn} do
      expected = %{
        hidden_images: false,
        site_notices: false,
        tags: false,
        users: false,
        forums: false,
        adverts: false,
        badges: false,
        static_pages: false,
        mod_notes: false,
        bans: false,
        moderation_log: false
      }

      user = user_fixture()
      assert tool_visibility(conn, nil) == expected
      assert tool_visibility(conn, user) == expected
    end

    test "a plain moderator sees core moderation tools only", %{conn: conn} do
      moderator = moderator_user_fixture()
      visibility = tool_visibility(conn, moderator)

      assert visibility == %{
               hidden_images: true,
               site_notices: false,
               tags: true,
               users: true,
               forums: false,
               adverts: false,
               badges: false,
               static_pages: false,
               mod_notes: true,
               bans: true,
               moderation_log: true
             }
    end

    test "resource role-map grants expose privileged staff tools", %{conn: conn} do
      privileged_moderator =
        role_user_fixture("moderator", [
          {"admin", "SiteNotice"},
          {"admin", "Tag"},
          {"moderator", "User"},
          {"admin", "Advert"},
          {"admin", "Badge"},
          {"admin", "StaticPage"}
        ])

      assert tool_visibility(conn, privileged_moderator) == %{
               hidden_images: true,
               site_notices: true,
               tags: true,
               users: true,
               forums: false,
               adverts: true,
               badges: true,
               static_pages: true,
               mod_notes: true,
               bans: true,
               moderation_log: true
             }
    end

    test "admins see every staff tool", %{conn: conn} do
      admin = admin_user_fixture()

      assert tool_visibility(conn, admin) == %{
               hidden_images: true,
               site_notices: true,
               tags: true,
               users: true,
               forums: true,
               adverts: true,
               badges: true,
               static_pages: true,
               mod_notes: true,
               bans: true,
               moderation_log: true
             }
    end
  end

  describe "_header_staff_links.html" do
    test "renders an assistant the mod notes and no ban menu", %{conn: conn} do
      response = staff_links(conn, assistant_user_fixture())

      assert response =~ ~s(title="Admin")
      assert response =~ "Mod Notes"
      refute response =~ ~s(title="Bans")
    end

    test "renders only the tools granted to a plain moderator", %{conn: conn} do
      moderator = moderator_user_fixture()
      response = staff_links(conn, moderator)

      assert response =~ "Users"
      assert response =~ "Mod Notes"
      assert response =~ "Mod Logs"
      assert response =~ "User Bans"
      assert response =~ "IP Bans"
      assert response =~ "FP Bans"

      refute response =~ "Site Notices"
      refute response =~ "Forums"
      refute response =~ "Adverts"
      refute response =~ "Badges"
      refute response =~ "Pages"
    end

    test "renders all resource-management links for an admin", %{conn: conn} do
      admin = admin_user_fixture()
      response = staff_links(conn, admin)

      for label <- [
            "Site Notices",
            "Users",
            "Forums",
            "Adverts",
            "Badges",
            "Pages",
            "Mod Notes",
            "Mod Logs",
            "User Bans",
            "IP Bans",
            "FP Bans"
          ] do
        assert response =~ label
      end
    end
  end

  describe "_notices.html" do
    test "renders the site notices, then the flash in the alert of its kind" do
      conn =
        build_conn()
        |> init_test_session(%{})
        |> fetch_flash()
        |> Phoenix.Controller.put_flash(:info, "Settings saved.")
        |> Phoenix.Controller.put_flash(:error, "Upload failed.")
        |> assign(:site_notices, [
          %SiteNotice{
            title: "Maintenance",
            text: "Tonight.",
            link: "/pages/news",
            link_text: "News"
          },
          %SiteNotice{title: "Contest", text: "Enter now."}
        ])

      html = Phoenix.View.render_to_string(LayoutView, "_notices.html", conn: conn)

      assert html =~ ~s(<strong>Maintenance</strong> Tonight.)
      assert html =~ ~s(<strong>Contest</strong> Enter now.)
      assert [_] = Regex.scan(~r/<a /, html)
      assert html =~ ~s(<a href="/pages/news">News</a>)
      assert html =~ ~s(<div class="alert alert-success">Settings saved.</div>)
      assert html =~ ~s(<div class="alert alert-danger">Upload failed.</div>)
    end
  end

  describe "current_page?/2" do
    test "matches a page and the section it belongs to, but no search" do
      conn = %Plug.Conn{request_path: "/forums/dis/topics/example"}

      assert LayoutView.current_page?(conn, "/forums")
      assert LayoutView.current_page?(conn, "/forums/dis")
      refute LayoutView.current_page?(conn, "/forum")
      refute LayoutView.current_page?(%Plug.Conn{request_path: "/tag_changes"}, "/tags")

      refute LayoutView.current_page?(
               %Plug.Conn{request_path: "/comments"},
               "/comments?cq=my:comments"
             )
    end
  end

  describe "header quick selects" do
    test "give a signed-in user the filter and, on wide screens, the spoiler type", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      response = conn |> get(~p"/forums") |> html_response(200)
      [header, _burger] = String.split(response, ~s(<div class="burger" id="burger"))

      assert header =~
               ~s(<form action="/filters/current" class="header-field" id="filter-quick-form")

      assert header =~
               ~s(<select aria-label="Filter" autocomplete="off" class="header-field-input")

      assert header =~ ~s(id="filter-quick-menu" name="id">)

      assert header =~
               ~s(<form action="/filters/spoiler_type" class="header-field hidden-below-xl" id="spoiler-quick-form")

      assert header =~
               ~s(<select aria-label="Spoilers" autocomplete="off" class="header-field-input")

      assert header =~ ~s(id="spoiler-quick-menu" name="settings[spoiler_type]">)
    end
  end

  describe "burger menu" do
    defp burger(response) do
      [_header, burger] =
        String.split(
          response,
          ~s(<div class="burger" id="burger" role="dialog" aria-modal="true" aria-label="Menu">)
        )

      burger |> String.split(~s(<div class="burger-overlay)) |> hd()
    end

    test "holds every page of the bars for staff and marks the current section", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      burger = conn |> get(~p"/forums") |> html_response(200) |> burger()

      assert burger =~ ~s(<a class="burger-item current" href="/forums">)
      refute burger =~ ~s(current" href="/images")
      assert burger =~ ~s(data-method="delete" href="/sessions")
      assert burger =~ ~s(id="filter-burger-menu")
      assert burger =~ ~s(id="spoiler-burger-menu")
      assert burger =~ ~s(<label for="spoiler-burger-menu">Spoilers</label>)

      for label <- ["Random", "Post Search", "Tag Changes", "Rankings", "Donate", "Watched"] do
        assert burger =~ label
      end

      # The hide staff tools setting hides .staff-action
      [_, staff_links] = String.split(burger, ~s(<div class="staff-action">))

      for label <- ["Site Notices", "Mod Logs", "User Bans", "FP Bans"] do
        assert staff_links =~ label
      end
    end

    test "offers anonymous visitors the filters and settings, and no account pages", %{conn: conn} do
      burger = conn |> get(~p"/forums") |> html_response(200) |> burger()

      assert burger =~ "Filters (Default)"
      assert burger =~ ~s(href="/settings/edit")
      refute burger =~ "Watched"
      refute burger =~ "Site Notices"
    end
  end

  describe "centering_class/1" do
    test "centers the page unless the signed-in user turned that off" do
      assert LayoutView.centering_class(nil) == "page-centered"
      assert LayoutView.centering_class(%User{settings: %Settings{}}) == "page-centered"

      assert LayoutView.centering_class(%User{settings: %Settings{use_centered_layout: false}}) ==
               nil
    end
  end

  describe "theme" do
    test "anonymous pages load no theme and follow the system color scheme", %{conn: conn} do
      response = html_response(get(conn, ~p"/settings/edit"), 200)

      assert response =~ ~s(<html lang="en">)
      refute response =~ "js-theme-stylesheet"
    end

    test "signed-in pages load the stylesheet of the theme's color, in its mode", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      patch(conn, ~p"/settings", %{
        "user" => %{"settings" => %{"theme_name" => "light", "theme_color" => "purple"}}
      })

      response = html_response(get(conn, ~p"/settings/edit"), 200)

      assert response =~ ~s(<html data-theme="light" lang="en">)

      assert response =~
               ~s(<link href="/css/purple.css" id="js-theme-stylesheet" rel="stylesheet">)
    end

    test "a theme that no longer exists falls back to dark blue" do
      user = %User{settings: %Settings{theme: "dark-neon"}}

      assert LayoutView.theme_mode(user) == "dark"
      assert LayoutView.user_stylesheet_path(user) == "/css/blue.css"
    end
  end
end
