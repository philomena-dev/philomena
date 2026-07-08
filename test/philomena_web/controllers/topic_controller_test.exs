defmodule PhilomenaWeb.TopicControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Topics.Topic
  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  describe "GET /forums/:forum_id/topics/:id" do
    test "renders a topic for anonymous users", %{conn: conn, forum: forum, topic: topic} do
      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}")
      response = html_response(conn, 200)

      assert response =~ "#{topic.title} - #{forum.name} - Forums - Derpibooru"
      assert response =~ "Test topic body"
    end

    test "renders a topic for logged-in users", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}")

      assert html_response(conn, 200) =~ "#{topic.title} - #{forum.name} - Forums - Derpibooru"
    end

    test "redirects to / for an unknown topic", %{conn: conn, forum: forum} do
      conn = get(conn, ~p"/forums/#{forum}/topics/nonexistent-topic")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / for an unknown forum", %{conn: conn, topic: topic} do
      conn = get(conn, ~p"/forums/nonexistent-forum/topics/#{topic}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "redirects to / for a hidden topic viewed anonymously", %{
      conn: conn,
      forum: forum,
      topic: topic
    } do
      topic
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end
  end

  describe "GET /:forum_id/:id (shorthand routes)" do
    test "renders a topic", %{conn: conn, forum: forum, topic: topic} do
      conn = get(conn, "/#{forum.short_name}/#{topic.slug}")

      assert html_response(conn, 200) =~ "#{topic.title} - #{forum.name} - Forums - Derpibooru"
    end

    test "renders a topic page", %{conn: conn, forum: forum, topic: topic} do
      conn = get(conn, "/#{forum.short_name}/#{topic.slug}/1")

      assert html_response(conn, 200) =~ "#{topic.title} - #{forum.name} - Forums - Derpibooru"
    end

    test "renders the page containing a given post", %{conn: conn, forum: forum, topic: topic} do
      post = post_fixture(topic, nil, %{"body" => "Test navigated post body"})

      conn = get(conn, "/#{forum.short_name}/#{topic.slug}/post/#{post.id}")

      assert html_response(conn, 200) =~ "Test navigated post body"
    end
  end

  describe "GET /forums/:forum_id/topics/new" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum} do
      conn = get(conn, ~p"/forums/#{forum}/topics/new")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "renders the form for logged-in users", %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      response = html_response(get(conn, ~p"/forums/#{forum}/topics/new"), 200)

      assert response =~ "New Topic - Derpibooru"
    end

    test "redirects banned users with the ban flash", %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = get(conn, ~p"/forums/#{forum}/topics/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "redirects to / for an unknown forum", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/forums/nonexistent-forum/topics/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /forums/:forum_id/topics" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum} do
      conn = post(conn, ~p"/forums/#{forum}/topics", %{})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "creates the topic and first post and redirects to it", %{conn: conn, forum: forum} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics", %{
          "topic" => %{
            "title" => "A brand new topic",
            "anonymous" => "false",
            "posts" => %{"0" => %{"body" => "First post body"}}
          }
        })

      topic =
        Repo.one!(from t in Topic, where: t.forum_id == ^forum.id and t.user_id == ^user.id)
        |> Repo.preload(:posts)

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully posted topic."
      assert topic.title == "A brand new topic"
      assert [%{body: "First post body"}] = topic.posts
    end

    test "re-renders the form when the title is too short", %{conn: conn, forum: forum} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics", %{
          "topic" => %{
            "title" => "abc",
            "anonymous" => "false",
            "posts" => %{"0" => %{"body" => "First post body"}}
          }
        })

      # the re-render is missing the :title assign (same shape as conversation
      # create failure); pin the form's error box instead
      response = html_response(conn, 200)
      assert response =~ "Oops, something went wrong! Please check the errors below."
      assert response =~ "Create a Topic"
      assert Repo.aggregate(from(t in Topic, where: t.user_id == ^user.id), :count) == 0
    end

    test "redirects banned users with the ban flash", %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end
  end

  describe "PATCH /forums/:forum_id/topics/:id" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn = patch(conn, ~p"/forums/#{forum}/topics/#{topic}", %{})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "redirects regular users (even the topic author) with the authorization flash",
         %{conn: conn, forum: forum} do
      # :edit on a Topic is a moderator-only ability; there is no owner rule
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      topic = topic_fixture(forum, user)

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}", %{
          "topic" => %{"title" => "Renamed by author"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(topic).title == topic.title
    end

    test "updates the title as a moderator without changing the slug",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}", %{
          "topic" => %{"title" => "Renamed by moderator"}
        })

      # the redirect still uses the original slug: title_changeset does not re-slug
      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated topic."

      reloaded = Repo.reload!(topic)
      assert reloaded.title == "Renamed by moderator"
      assert reloaded.slug == topic.slug
    end

    test "PUT also updates the title", %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        put(conn, ~p"/forums/#{forum}/topics/#{topic}", %{
          "topic" => %{"title" => "Renamed via PUT"}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Repo.reload!(topic).title == "Renamed via PUT"
    end

    test "redirects back to the topic with the error flash when the title is too short",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/#{topic}", %{"topic" => %{"title" => "abc"}})

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "There was an error with your submission. Please try again."

      assert Repo.reload!(topic).title == topic.title
    end

    test "redirects to / with the not-found flash for an unknown topic",
         %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/forums/#{forum}/topics/nonexistent-topic", %{
          "topic" => %{"title" => "Renamed"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end
end
