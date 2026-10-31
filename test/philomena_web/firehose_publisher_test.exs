defmodule PhilomenaWeb.FirehosePublisherTest do
  use Philomena.DataCase, async: true

  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Phoenix.Socket.Broadcast
  alias Philomena.Events
  alias PhilomenaWeb.Endpoint

  test "renders every internal event as the corresponding firehose broadcast" do
    user = confirmed_user_fixture()

    image =
      image_fixture(user_id: user.id, sources: ["https://example.test/source"])
      |> Repo.preload([:user, :sources, tags: :aliases])

    duplicate_of_image =
      image_fixture()
      |> Repo.preload([:user, :sources, tags: :aliases])

    comment =
      image
      |> comment_fixture(user)
      |> Repo.preload([:user, :image])

    forum = forum_fixture()
    topic = forum |> topic_fixture(user) |> Repo.preload(:user, force: true)
    post = topic.posts |> hd() |> Repo.preload([:user, :topic], force: true)

    image_id = image.id
    duplicate_of_image_id = duplicate_of_image.id
    comment_id = comment.id
    post_id = post.id
    topic_slug = topic.slug
    forum_short_name = forum.short_name

    :ok = Endpoint.subscribe("firehose")

    Events.broadcast(%Events.CommentCreate{comment: comment})

    assert_receive %Broadcast{
      event: "comment:create",
      payload: %{comment: %{id: ^comment_id}}
    }

    Events.broadcast(%Events.CommentUpdate{comment: comment})

    assert_receive %Broadcast{
      event: "comment:update",
      payload: %{comment: %{id: ^comment_id}}
    }

    Events.broadcast(%Events.ImageBatchUpdate{
      image_ids: [image_id],
      added_tag_names: ["safe"],
      removed_tag_names: ["questionable"]
    })

    assert_receive %Broadcast{
      event: "image:batch_tag_update",
      payload: %{
        image_ids: [^image_id],
        added: ["safe"],
        removed: ["questionable"]
      }
    }

    Events.broadcast(%Events.ImageCreate{image: image})

    assert_receive %Broadcast{
      event: "image:create",
      payload: %{image: %{id: ^image_id}, interactions: []}
    }

    Events.broadcast(%Events.ImageDescriptionUpdate{
      image_id: image_id,
      new_description: "New description",
      old_description: "Old description"
    })

    assert_receive %Broadcast{
      event: "image:description_update",
      payload: %{
        image_id: ^image_id,
        added: "New description",
        removed: "Old description"
      }
    }

    Events.broadcast(%Events.ImageMerge{
      image: image,
      duplicate_of_image: duplicate_of_image
    })

    assert_receive %Broadcast{
      event: "image:merge",
      payload: %{
        image: %{id: ^image_id},
        duplicate_of_image: %{id: ^duplicate_of_image_id}
      }
    }

    Events.broadcast(%Events.ImageProcess{image_id: image_id})

    assert_receive %Broadcast{
      event: "image:process",
      payload: %{image_id: ^image_id}
    }

    Events.broadcast(%Events.ImageSourceUpdate{
      image_id: image_id,
      added_sources: ["https://example.test/new"],
      removed_sources: ["https://example.test/old"]
    })

    assert_receive %Broadcast{
      event: "image:source_update",
      payload: %{
        image_id: ^image_id,
        added: ["https://example.test/new"],
        removed: ["https://example.test/old"]
      }
    }

    Events.broadcast(%Events.ImageTagUpdate{
      image_id: image_id,
      added_tag_names: ["safe"],
      removed_tag_names: ["questionable"]
    })

    assert_receive %Broadcast{
      event: "image:tag_update",
      payload: %{image_id: ^image_id, added: ["safe"], removed: ["questionable"]}
    }

    Events.broadcast(%Events.ImageUpdate{image: image})

    assert_receive %Broadcast{
      event: "image:update",
      payload: %{image: %{id: ^image_id}, interactions: []}
    }

    Events.broadcast(%Events.PostCreate{forum: forum, topic: topic, post: post})

    assert_receive %Broadcast{
      event: "post:create",
      payload: %{
        post: %{id: ^post_id},
        topic: %{slug: ^topic_slug},
        forum: %{short_name: ^forum_short_name}
      }
    }
  end
end
