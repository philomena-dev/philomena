# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Philomena.Repo.insert!(%Philomena.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Philomena.{
  Repo,
  Comments.Comment,
  Filters.Filter,
  Forums.Forum,
  Galleries.Gallery,
  Posts.Post,
  Images.Image,
  Reports.Report,
  Filters.Filter,
  Roles.Role,
  Tags.Tag,
  TagChanges.TagChange,
  Users.User,
  StaticPages.StaticPage,
  FooterLinks,
  QuickTags,
  Avatars
}

alias PhilomenaQuery.Search
alias Philomena.Users
alias Philomena.Tags
alias Philomena.Filters
import Ecto.Query

defmodule Philomena.SeedLoader do
  def load_resource(res) do
    "priv/repo/seeds/data/#{res}.json"
    |> File.read!()
    |> JSON.decode!()
  end
end

alias Philomena.SeedLoader

IO.puts("---- Creating search indices")

for model <- [Image, Comment, Gallery, Tag, TagChange, Post, Report, Filter] do
  Search.delete_index!(model)
  Search.create_index!(model)
end

IO.puts("---- Generating rating tags")

for tag_name <- SeedLoader.load_resource("rating_tags") do
  %Tag{category: "rating"}
  |> Tag.creation_changeset(%{name: tag_name})
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Generating invalid tags")

for tag_name <- SeedLoader.load_resource("invalid_tags") do
  %Tag{invalid: true}
  |> Tag.creation_changeset(%{name: tag_name})
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Generating footer links and categories")

footer_data = SeedLoader.load_resource("footer")

for {category, cat_index} <- Enum.with_index(footer_data["categories"]) do
  {:ok, footer_category} =
    %FooterLinks.Category{title: category, position: cat_index}
    |> Repo.insert(on_conflict: :nothing)

  for {link_def, link_index} <- Enum.with_index(footer_data[category]) do
    %FooterLinks.Link{}
    |> FooterLinks.Link.changeset(%{
      title: link_def["title"],
      url: link_def["url"],
      bold: link_def["bold"] || false,
      new_tab: link_def["new_tab"] || false,
      position: link_index,
      footer_category_id: footer_category.id
    })
    |> Repo.insert(on_conflict: :nothing)
  end
end

IO.puts("---- Generating quick tags table")

quick_tags = SeedLoader.load_resource("quick_tags")

IO.puts("     ...tabs")

quick_tag_tabs =
  quick_tags["quick_tag_tabs"]
  |> Enum.map(fn tab ->
    {:ok, tab_record} =
      %QuickTags.Tab{title: tab["title"], position: tab["position"]}
      |> Repo.insert(on_conflict: :nothing)

    {tab["title"], tab_record}
  end)
  |> Map.new()

IO.puts("     ...shorthand categories")

shorthand_categories =
  quick_tags["shorthand_quick_tag_categories"]
  |> Enum.map(fn cat ->
    {:ok, cat_record} =
      %QuickTags.ShorthandCategory{
        category: cat["category"],
        quick_tag_tab_id: quick_tag_tabs[cat["tab_title"]]
      }
      |> Repo.insert(on_conflict: :nothing)

    {cat["category"], cat_record}
  end)
  |> Map.new()

IO.puts("     ...default quick tags")

for tag <- quick_tags["default_quick_tags"] do
  {:ok, _} =
    %QuickTags.Default{
      category: tag["category"],
      tags: tag["tags"],
      quick_tag_tab_id: quick_tag_tabs[tag["tab_title"]].id
    }
    |> Repo.insert(on_conflict: :nothing)
end

IO.puts("     ...shorthand quick tags")

for tag <- quick_tags["shorthand_quick_tags"] do
  {:ok, _} =
    %QuickTags.Shorthand{
      shorthand: tag["shorthand"],
      tag: tag["tag"],
      shorthand_quick_tag_category_id: shorthand_categories[tag["category"]].id
    }
    |> Repo.insert(on_conflict: :nothing)
end

IO.puts("     ...season quick tags")

for tag <- quick_tags["season_quick_tags"] do
  {:ok, _} =
    %QuickTags.Season{
      episode: tag["episode"],
      tag: tag["tag"],
      quick_tag_tab_id: quick_tag_tabs[tag["tab_title"]].id
    }
    |> Repo.insert(on_conflict: :nothing)
end

IO.puts("     ...shipping quick tags")

for tag <- quick_tags["shipping_quick_tags"] do
  {:ok, _} =
    %QuickTags.Shipping{
      category: tag["category"],
      implying: tag["implying"],
      not_implying: tag["not_implying"],
      quick_tag_tab_id: quick_tag_tabs[tag["tab_title"]].id
    }
    |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Generating avatar data")

avatar_data = SeedLoader.load_resource("avatar")

IO.puts("     ... parts")

avatar_parts =
  Enum.with_index(avatar_data["parts"])
  |> Enum.map(fn {part, index} ->
    {:ok, record} =
      %Avatars.Part{}
      |> Avatars.Part.changeset(%{
        name: part,
        priority: index
      })
      |> Repo.insert(on_conflict: :nothing)

    {part, record}
  end)
  |> Map.new()

IO.puts("     ...kinds")

avatar_kinds =
  Enum.with_index(avatar_data["kinds"])
  |> Enum.map(fn {kind, index} ->
    {:ok, record} =
      %Avatars.Kind{}
      |> Avatars.Kind.changeset(%{
        name: kind
      })
      |> Repo.insert(on_conflict: :nothing)

    {kind, record}
  end)
  |> Map.new()

IO.puts("     ...shapes")

for {part, shapes} <- avatar_data["shapes"] do
  for shape_def <- shapes do
    {:ok, shape_record} =
      %Avatars.Shape{}
      |> Avatars.Shape.changeset(%{
        avatar_part_id: avatar_parts[part].id,
        shape: shape_def["shape"],
        any_kind: shape_def["any_kind"] || false
      })
      |> Repo.insert(on_conflict: :nothing)

    for kind <- shape_def["kinds"] do
      %Avatars.ShapeKind{}
      |> Avatars.ShapeKind.changeset(%{
        avatar_shape_id: shape_record.id,
        avatar_kind_id: avatar_kinds[kind].id
      })
      |> Repo.insert(on_conflict: :nothing)
    end
  end
end

IO.puts("---- Generating system filters")

for filter_def <- SeedLoader.load_resource("system_filters") do
  spoilered_tag_list = Enum.join(filter_def["spoilered"], ",")
  hidden_tag_list = Enum.join(filter_def["hidden"], ",")

  %Filter{system: true}
  |> Filter.changeset(%{
    name: filter_def["name"],
    description: filter_def["description"],
    spoilered_tag_list: spoilered_tag_list,
    hidden_tag_list: hidden_tag_list
  })
  |> Repo.insert(on_conflict: :nothing)
  |> case do
    {:ok, filter} ->
      Filters.reindex_filter(filter)

    {:error, changeset} ->
      IO.inspect(changeset.errors)
  end
end

IO.puts("---- Generating forums")

for forum_def <- SeedLoader.load_resource("forums") do
  %Forum{}
  |> Forum.changeset(forum_def)
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Generating users")

for user_def <- SeedLoader.load_resource("users") do
  {:ok, user} = Users.register_user(user_def)

  user
  |> Repo.preload([:roles])
  |> User.confirm_changeset()
  |> User.update_changeset(%{role: user_def["role"]}, [])
  |> Repo.update!()
end

IO.puts("---- Generating roles")

for role_def <- SeedLoader.load_resource("roles") do
  %Role{name: role_def["name"], resource_type: role_def["resource_type"]}
  |> Role.changeset(%{})
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Generating static pages")

for page_def <- SeedLoader.load_resource("pages") do
  %StaticPage{
    title: page_def["title"],
    slug: page_def["slug"],
    body: File.read!("priv/repo/seeds/data/pages/#{page_def["slug"]}.md")
  }
  |> StaticPage.changeset(%{})
  |> Repo.insert(on_conflict: :nothing)
end

IO.puts("---- Indexing content")
Search.reindex(Tag |> preload(^Tags.indexing_preloads()), Tag)

IO.puts("---- Done.")
