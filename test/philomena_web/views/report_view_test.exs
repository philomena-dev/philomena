defmodule PhilomenaWeb.ReportViewTest do
  use ExUnit.Case, async: true

  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Forums.Forum
  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image
  alias Philomena.Posts.Post
  alias Philomena.Topics.Topic
  alias Philomena.Users.User
  alias PhilomenaWeb.ReportView

  test "the state cell is colored and named by the report state" do
    for {state, class, name} <- [
          {"closed", "table-success", "Closed"},
          {"in_progress", "table-warning", "In progress"},
          {"claimed", "table-danger", "Claimed"},
          {"open", "table-danger", "Open"}
        ] do
      assert ReportView.report_row_class(%{state: state}) == class
      assert ReportView.pretty_state(%{state: state}) == name
    end
  end

  test "links the target of a report as a stand-alone link, or says it is gone" do
    image = %Image{id: 1}
    user = %User{name: "Pleb", slug: "pleb"}
    topic = %Topic{title: "Hello", slug: "hello", forum: %Forum{short_name: "dis"}}

    for {target, text, path} <- [
          {image, "Image >>1", "/images/1"},
          {%Comment{id: 2, image: image}, "Comment on image >>1", "/images/1#comment_2"},
          {%Conversation{slug: "chat", from: user, to: %User{name: "Admin"}},
           "Conversation between Pleb and Admin", "/conversations/chat"},
          {%Commission{user: user}, "Pleb's commission page", "/profiles/pleb/commission"},
          {%Gallery{id: 3, title: "Pics"}, "Gallery 'Pics'", "/galleries/3"},
          {%Post{id: 4, topic: topic}, "Post in Hello",
           "/forums/dis/topics/hello?post_id=4#post_4"},
          {user, "User 'Pleb'", "/profiles/pleb"}
        ] do
      assert Phoenix.HTML.safe_to_string(ReportView.link_to_target(target)) ==
               ~s(<a class="touch-link" href="#{path}">) <>
                 Phoenix.HTML.safe_to_string(Phoenix.HTML.html_escape(text)) <> "</a>"
    end

    assert ReportView.link_to_target(nil) == "Reported item permanently destroyed."
  end
end
