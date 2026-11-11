defmodule PhilomenaWeb.CommunicationViewTest do
  use ExUnit.Case, async: true

  alias Philomena.Comments.Comment
  alias Philomena.Forums.Forum
  alias Philomena.Posts.Post
  alias Philomena.Topics.Topic
  alias Philomena.Users.User
  alias PhilomenaWeb.CommunicationView

  @comment %Comment{id: 2, image_id: 1}
  @post %Post{id: 4, topic: %Topic{slug: "hello", forum: %Forum{short_name: "dis"}}}

  test "names comments and posts and paths their place and every action on them" do
    assert CommunicationView.noun(@comment) == :comment
    assert CommunicationView.noun(@post) == :post

    assert CommunicationView.communication_path(@comment, :link) == "/images/1#comment_2"

    assert CommunicationView.communication_path(@post, :link) ==
             "/forums/dis/topics/hello?post_id=4#post_4"

    for {action, path} <- [
          report: "reports/new",
          approve: "approve",
          hide: "hide",
          delete: "delete",
          history: "history",
          edit: "edit"
        ] do
      assert CommunicationView.communication_path(@comment, action) ==
               "/images/1/comments/2/#{path}"

      assert CommunicationView.communication_path(@post, action) ==
               "/forums/dis/topics/hello/posts/4/#{path}"
    end
  end

  test "quotes the author as a Markdown-safe mention that keeps anonymous authors anonymous" do
    user = %User{id: 7, name: "*Pleb*"}
    author = &CommunicationView.markdown_safe_author(struct(@comment, &1))
    pseudonym = ~r/\A@Background Pony \\#[0-9A-F]{4}\z/

    assert author.(user: user) == "@\\*Pleb\\*"
    assert author.(user: user, user_id: 7, anonymous: true) =~ pseudonym
    assert author.(user: nil, ip: %Postgrex.INET{address: {127, 0, 0, 1}}) =~ pseudonym
  end
end
