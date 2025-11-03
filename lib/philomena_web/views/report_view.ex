defmodule PhilomenaWeb.ReportView do
  use PhilomenaWeb, :view

  alias Philomena.Images.Image
  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Galleries.Gallery
  alias Philomena.Posts.Post
  alias Philomena.Users.User
  alias Philomena.Rules

  import Ecto.Changeset

  def report_categories do
    Rules.list_report_categories()
  end

  def image?(changeset), do: get_field(changeset, :reportable_type) == "Image"
  def conversation?(changeset), do: get_field(changeset, :reportable_type) == "Conversation"

  def report_row_class(%{state: "closed"}), do: "success"
  def report_row_class(%{state: "in_progress"}), do: "warning"
  def report_row_class(_report), do: "danger"

  def pretty_state(%{state: "closed"}), do: "Closed"
  def pretty_state(%{state: "in_progress"}), do: "In progress"
  def pretty_state(%{state: "claimed"}), do: "Claimed"
  def pretty_state(_report), do: "Open"

  def link_to_reportable(%Image{} = r),
    do: link("Image >>#{r.id}", to: ~p"/images/#{r}")

  def link_to_reportable(%Comment{} = r),
    do:
      link("Comment on image >>#{r.image.id}",
        to: ~p"/images/#{r.image}" <> "#comment_#{r.id}"
      )

  def link_to_reportable(%Conversation{} = r),
    do:
      link("Conversation between #{r.from.name} and #{r.to.name}",
        to: ~p"/conversations/#{r}"
      )

  def link_to_reportable(%Commission{} = r),
    do:
      link("#{r.user.name}'s commission page",
        to: ~p"/profiles/#{r.user}/commission"
      )

  def link_to_reportable(%Gallery{} = r),
    do: link("Gallery '#{r.title}'", to: ~p"/galleries/#{r}")

  def link_to_reportable(%Post{} = r),
    do:
      link("Post in #{r.topic.title}",
        to:
          ~p"/forums/#{r.topic.forum}/topics/#{r.topic}?#{[post_id: r.id]}" <>
            "#post_#{r.id}"
      )

  def link_to_reportable(%User{} = r),
    do: link("User '#{r.name}'", to: ~p"/profiles/#{r}")

  def link_to_reportable(_reportable) do
    "Reported item permanently destroyed."
  end

  def get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua] -> ua
      _ -> ""
    end
  end
end
