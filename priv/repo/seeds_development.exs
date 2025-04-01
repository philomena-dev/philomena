# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds_development.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Philomena.Repo.insert!(%Philomena.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

defmodule Philomena.DevSeeds do
  alias Philomena.{Repo, Forums.Forum, Users, Users.User}
  alias Philomena.Comments
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Topics
  alias Philomena.Posts
  alias Philomena.Tags
  import Ecto.Query
  require Logger

  def seed() do
    exclude_log_event? = fn event ->
      # Skip DB logs, they are too verbose
      Map.get(event.meta, :application) == :ecto_sql
    end

    :logger.add_primary_filter(
      :sql_logs,
      {fn event, _ -> if(exclude_log_event?.(event), do: :stop, else: :ignore) end, []}
    )

    {:ok, _} = Application.ensure_all_started(:plug)

    communications =
      "priv/repo/seeds/dev/communications.json"
      |> File.read!()
      |> Jason.decode!()

    # pages =
    #   "priv/repo/seeds/dev/pages.json"
    #   |> File.read!()
    #   |> Jason.decode!()

    users =
      "priv/repo/seeds/dev/users.json"
      |> File.read!()
      |> Jason.decode!()

    IO.puts("---- Generating users")

    for user_def <- users do
      {:ok, user} = Users.register_user(user_def)

      user
      |> Repo.preload([:roles])
      |> User.confirm_changeset()
      |> User.update_changeset(%{role: user_def["role"]}, [])
      |> Repo.update!()
    end

    users = Repo.all(User)
    pleb = Repo.get_by!(User, name: "Pleb")
    pleb_attrs = request_attrs(pleb)

    IO.puts("---- Generating images")

    generate_images(pleb_attrs)

    IO.puts("---- Generating comments for image #1")

    for comment_body <- communications["demos"] do
      image = Images.get_image!(1)

      Comments.create_comment(
        image,
        pleb_attrs,
        %{"body" => comment_body}
      )
      |> case do
        {:ok, %{comment: comment}} ->
          Comments.approve_comment(comment, pleb)
          Comments.reindex_comment(comment)
          Images.reindex_image(image)

        {:error, :comment, changeset, _so_far} ->
          IO.inspect(changeset.errors)
      end
    end

    all_imgs = Image |> where([i], i.id > 1) |> Repo.all()

    IO.puts("---- Generating random comments for images other than 1")

    for _ <- 1..1000 do
      image = Enum.random(all_imgs)
      user = random_user(users)

      Comments.create_comment(
        image,
        request_attrs(user),
        %{"body" => random_body(communications)}
      )
      |> case do
        {:ok, %{comment: comment}} ->
          Comments.approve_comment(comment, user)
          Comments.reindex_comment(comment)
          Images.reindex_image(image)

        {:error, :comment, changeset, _so_far} ->
          IO.inspect(changeset.errors)
      end
    end

    IO.puts("---- Generating forum posts")

    for _ <- 1..500 do
      random_topic_no_replies(communications, users)
    end

    for _ <- 1..20 do
      random_topic(communications, users)
    end

    IO.puts("---- Done.")

    Logger.configure(level: :debug)
  end

  defp generate_images(pleb_attrs) do
    images =
      "priv/repo/seeds/dev/images.json"
      |> File.read!()
      |> Jason.decode!()

    ingest_image = fn image_def ->
      file = Briefly.create!()
      now = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

      IO.puts("[Images] Fetching #{image_def["url"]} ...")
      {:ok, %{body: body}} = PhilomenaProxy.Http.get(image_def["url"])

      File.write!(file, body)

      upload = %Plug.Upload{
        path: file,
        content_type: "application/octet-stream",
        filename: "fixtures-#{now}"
      }

      IO.puts("[Images] Creating image ...")

      Images.create_image(pleb_attrs, Map.merge(image_def, %{"image" => upload}))
      |> case do
        {:ok, %{image: image, upload_pid: upload_pid}} ->
          # Delete the temp file only after the async image upload finishes
          Briefly.give_away(file, upload_pid)

          Images.approve_image(image)
          Images.reindex_image(image)
          Tags.reindex_tags(image.added_tags)

          IO.puts("[Images] Created image ##{image.id}")

        {:error, :image, changeset, _so_far} ->
          IO.inspect(changeset.errors)
      end
    end

    images
    |> Task.async_stream(ingest_image, max_concurrency: 100, ordered: false)
    |> Stream.run()
  end

  defp default_ip() do
    {:ok, ip} = EctoNetwork.INET.cast({203, 0, 113, 0})
    ip
  end

  defp available_forums(), do: ["dis", "art", "rp", "meta", "shows"]

  defp random_forum(), do: Enum.random(available_forums())

  defp random_user(users), do: Enum.random(users)

  defp request_attrs(%{id: id} = user) do
    [
      fingerprint: "d015c342859dde3",
      ip: default_ip(),
      user_id: id,
      user: user
    ]
  end

  defp random_body(%{"random" => random}) do
    count = :rand.uniform(3)

    0..count
    |> Enum.map(fn _ -> Enum.random(random) end)
    |> Enum.join("\n\n")
  end

  defp random_title(%{"titles" => titles}) do
    Enum.random(titles["first"]) <>
      " " <>
      Enum.random(titles["second"]) <>
      " " <>
      Enum.random(titles["third"])
  end

  defp random_topic(comm, users) do
    forum = Repo.get_by!(Forum, short_name: random_forum())
    op = random_user(users)

    Topics.create_topic(
      forum,
      request_attrs(op),
      %{
        "title" => random_title(comm),
        "posts" => %{
          "0" => %{
            "body" => random_body(comm)
          }
        }
      }
    )
    |> case do
      {:ok, %{topic: topic}} ->
        IO.puts("  -> created topic ##{topic.id}")
        count = :rand.uniform(250) + 5

        for _ <- 1..count do
          user = random_user(users)

          Posts.create_post(
            topic,
            request_attrs(user),
            %{"body" => random_body(comm)}
          )
          |> case do
            {:ok, %{post: post}} ->
              Posts.approve_post(post, op)
              Posts.reindex_post(post)

            {:error, :post, changeset, _so_far} ->
              IO.inspect(changeset.errors)
          end
        end

        IO.puts("    -> created #{count} replies for topic ##{topic.id}")

      {:error, :topic, changeset, _so_far} ->
        IO.inspect(changeset.errors)
    end
  end

  defp random_topic_no_replies(comm, users) do
    forum = Repo.get_by!(Forum, short_name: random_forum())
    op = random_user(users)

    Topics.create_topic(
      forum,
      request_attrs(op),
      %{
        "title" => random_title(comm),
        "posts" => %{
          "0" => %{
            "body" => random_body(comm)
          }
        }
      }
    )
    |> case do
      {:ok, %{topic: topic}} ->
        IO.puts("  -> created topic ##{topic.id}")

      {:error, :topic, changeset, _so_far} ->
        IO.inspect(changeset.errors)
    end
  end
end

Philomena.DevSeeds.seed()
