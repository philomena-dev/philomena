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
  Forums.Forum,
  Galleries.Gallery,
  Posts.Post,
  Images.Image,
  Reports.Report,
  Filters.Filter,
  Roles.Role,
  Tags.Tag,
  Users.User,
  StaticPages.StaticPage
}

alias PhilomenaQuery.Search
alias Philomena.Users
alias Philomena.Tags
alias Philomena.Filters
require Logger
import Ecto.Query

Logger.info("---- Creating OpenSearch indices")

[Image, Comment, Gallery, Tag, Post, Report, Filter]
|> Task.async_stream(
  fn model ->
    Search.delete_index!(model)
    Search.create_index!(model)
    Logger.info("OpenSearch index created: #{inspect(model)}")
  end,
  timeout: 15_000
)
|> Stream.run()

resources =
  "priv/repo/seeds/seeds.json"
  |> File.read!()
  |> Jason.decode!()

Logger.info("---- Generating rating tags")

for tag_name <- resources["rating_tags"] do
  %Tag{category: "rating"}
  |> Tag.creation_changeset(%{name: tag_name})
  |> Repo.insert(on_conflict: :nothing)
end

Logger.info("---- Generating system filters")

for filter_def <- resources["system_filters"] do
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

Logger.info("---- Generating forums")

for forum_def <- resources["forums"] do
  %Forum{}
  |> Forum.changeset(forum_def)
  |> Repo.insert(on_conflict: :nothing)
end

Logger.info("---- Generating users")

for user_def <- resources["users"] do
  {:ok, user} = Users.register_user(user_def)

  user
  |> Repo.preload([:roles])
  |> User.confirm_changeset()
  |> User.update_changeset(%{role: user_def["role"]}, [])
  |> Repo.update!()
end

Logger.info("---- Generating roles")

for role_def <- resources["roles"] do
  %Role{name: role_def["name"], resource_type: role_def["resource_type"]}
  |> Role.changeset(%{})
  |> Repo.insert(on_conflict: :nothing)
end

Logger.info("---- Generating static pages")

for page_def <- resources["pages"] do
  %StaticPage{title: page_def["title"], slug: page_def["slug"], body: page_def["body"]}
  |> StaticPage.changeset(%{})
  |> Repo.insert(on_conflict: :nothing)
end

Logger.info("---- Indexing content")
Search.reindex(Tag |> preload(^Tags.indexing_preloads()), Tag)

Logger.info("---- Done.")
