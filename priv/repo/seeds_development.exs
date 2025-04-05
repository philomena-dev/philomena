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
    {:ok, _} = Application.ensure_all_started(:plug)

    communications =
      "priv/repo/seeds/dev/communications.json"
      |> File.read!()
      |> Jason.decode!()

    # TODO: add pages to the seeds too
    # pages =
    #   "priv/repo/seeds/dev/pages.json"
    #   |> File.read!()
    #   |> Jason.decode!()

    Logger.info("---- Generating users")

    generate_users()

    users = Repo.all(User)
    pleb = Repo.get_by!(User, name: "Pleb")
    pleb_attrs = request_attrs(pleb)

    Logger.info("---- Generating images")

    generate_images(pleb_attrs)

    last_image_id = Image |> Repo.aggregate(:max, :id)

    Logger.info("---- Generating comments for image #{last_image_id}")

    generate_predefined_image_comments(pleb, pleb_attrs, communications, last_image_id)

    other_images = Image |> where([i], i.id != ^last_image_id) |> Repo.all()

    Logger.info("---- Generating random comments for images other than 1")

    generate_random_image_comments(other_images, users, communications)

    Logger.info("---- Generating forum posts")

    forums = Repo.all(Forum)

    topic_params = %{
      communications: communications,
      users: users,
      forums: forums
    }

    1..500
    |> Task.async_stream(fn _ -> generate_topic_without_posts(topic_params) end)
    |> Stream.run()

    500..520
    |> Task.async_stream(fn _ -> generate_topic_with_posts(topic_params) end)
    |> Stream.run()

    Logger.info("---- Done.")
  end

  defp generate_users() do
    users =
      "priv/repo/seeds/dev/users.json"
      |> File.read!()
      |> Jason.decode!()

    users
    |> Task.async_stream(
      fn user_def ->
        {:ok, user} = Users.register_user(user_def)

        user
        |> Repo.preload([:roles])
        |> User.confirm_changeset()
        |> User.update_changeset(%{role: user_def["role"]}, [])
        |> Repo.update!()
      end,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp generate_images(pleb_attrs) do
    images =
      "priv/repo/seeds/dev/images.json"
      |> File.read!()
      |> Jason.decode!()

    generate_image = fn image_def ->
      file = Briefly.create!()
      now = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

      {:ok, %{body: body}} = PhilomenaProxy.Http.get(image_def["url"])

      Logger.info("[Images] Fetched #{image_def["url"]}")

      File.write!(file, body)

      upload = %Plug.Upload{
        path: file,
        content_type: "application/octet-stream",
        filename: "fixtures-#{now}"
      }

      Logger.info("[Images] Creating image ...")

      Images.create_image(pleb_attrs, Map.merge(image_def, %{"image" => upload}))
      |> case do
        {:ok, %{image: image, upload_pid: upload_pid}} ->
          # Delete the temp file only after the async image upload finishes
          Briefly.give_away(file, upload_pid)

          Images.approve_image(image)
          Images.reindex_image(image)
          Tags.reindex_tags(image.added_tags)

          Logger.info("[Images] Created image ##{image.id}")

        {:error, :image, changeset, _so_far} ->
          Logger.error(inspect(changeset.errors))
      end
    end

    images
    |> Task.async_stream(generate_image)
    |> Stream.run()
  end

  defp generate_predefined_image_comments(pleb, pleb_attrs, communications, image_id) do
    generate_comment = fn comment_body ->
      image = Images.get_image!(image_id)

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
          Logger.error(inspect(changeset.errors))
      end
    end

    communications["demos"]
    |> Task.async_stream(generate_comment)
    |> Stream.run()
  end

  defp generate_random_image_comments(images, users, communications) do
    generate_comment = fn _ ->
      image = Enum.random(images)
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
          Logger.error(inspect(changeset.errors))
      end
    end

    1..1000
    |> Task.async_stream(generate_comment)
    |> Stream.run()
  end

  defp default_ip() do
    {:ok, ip} = EctoNetwork.INET.cast({203, 0, 113, 0})
    ip
  end

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

  # `nonce` is a unique number for each topic that is used in the title to make
  # sure we don't generate conflicting titles
  defp random_title(%{"titles" => titles}) do
    [
      Enum.random(titles["first"]),
      Enum.random(titles["second"]),
      Enum.random(titles["third"])
    ]
    |> Enum.join(" ")
  end

  defp generate_topic_posts(params, topic, op) do
    count = :rand.uniform(250) + 5

    generate_post = fn _ ->
      user = random_user(params.users)

      Posts.create_post(
        topic,
        request_attrs(user),
        %{"body" => random_body(params.communications)}
      )
      |> case do
        {:ok, %{post: post}} ->
          Posts.approve_post(post, op)
          Posts.reindex_post(post)

        {:error, :post, changeset, _so_far} ->
          Logger.error("Failed to create a post: #{inspect(changeset.errors)}")
      end
    end

    1..count
    |> Task.async_stream(generate_post, timeout: :infinity)

    Logger.info("[Topics] Created topic ##{topic.id} with #{count} replies")
  end

  defp generate_topic_with_posts(params) do
    result = generate_topic(params)

    if !is_nil(result) do
      {topic, op} = result
      generate_topic_posts(params, topic, op)
    end
  end

  defp generate_topic_without_posts(params) do
    result = generate_topic(params)

    if !is_nil(result) do
      {topic, _op} = result
      Logger.info("[Topics] Created topic ##{topic.id}")
    end
  end

  defp generate_topic(params) do
    forum = Enum.random(params.forums)
    op = random_user(params.users)
    title = random_title(params.communications)

    Topics.create_topic(
      forum,
      request_attrs(op),
      %{
        "title" => title,
        "posts" => %{
          "0" => %{
            "body" => random_body(params.communications)
          }
        }
      }
    )
    |> case do
      {:ok, %{topic: topic}} ->
        {topic, op}

      {:error, :topic, %{errors: errors}, _changes_so_far} ->
        if inspect(errors) |> String.contains?("already exists") do
          Logger.info("[Topics] Random title collision (#{title}), retrying...")
          generate_topic(params)
        else
          Logger.error("[Topics] Failed to create a topic: #{inspect(errors)}")
          nil
        end
    end
  end
end

Philomena.DevSeeds.seed()
