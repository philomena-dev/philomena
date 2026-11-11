defmodule PhilomenaWeb.ReportView do
  use PhilomenaWeb, :view

  alias Philomena.Images.Image
  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Galleries.Gallery
  alias Philomena.Posts.Post
  alias Philomena.Users.User
  alias Philomena.Reports.Report
  import Ecto.Changeset

  def report_categories(rules),
    do: Enum.map(rules, &{"#{&1.name}: #{&1.short_description}", &1.id})

  def image?(changeset), do: not is_nil(get_field(changeset, :image_id))
  def conversation?(changeset), do: not is_nil(get_field(changeset, :conversation_id))

  def report_row_class(%{state: "closed"}), do: "table-success"
  def report_row_class(%{state: "in_progress"}), do: "table-warning"
  def report_row_class(_report), do: "table-danger"

  def pretty_state(%{state: "closed"}), do: "Closed"
  def pretty_state(%{state: "in_progress"}), do: "In progress"
  def pretty_state(%{state: "claimed"}), do: "Claimed"
  def pretty_state(_report), do: "Open"

  # The loaded target struct of a report, or `nil` when the report is orphaned
  # (all target foreign key columns NULL because the target was deleted).
  def report_target(%Report{image: %Image{} = t}), do: t
  def report_target(%Report{comment: %Comment{} = t}), do: t
  def report_target(%Report{post: %Post{} = t}), do: t
  def report_target(%Report{reported_user: %User{} = t}), do: t
  def report_target(%Report{commission: %Commission{} = t}), do: t
  def report_target(%Report{conversation: %Conversation{} = t}), do: t
  def report_target(%Report{gallery: %Gallery{} = t}), do: t
  def report_target(%Report{}), do: nil

  def link_to_target(%Image{} = r), do: target_link("Image >>#{r.id}", ~p"/images/#{r}")

  def link_to_target(%Comment{} = r),
    do:
      target_link(
        "Comment on image >>#{r.image.id}",
        ~p"/images/#{r.image}" <> "#comment_#{r.id}"
      )

  def link_to_target(%Conversation{} = r),
    do:
      target_link("Conversation between #{r.from.name} and #{r.to.name}", ~p"/conversations/#{r}")

  def link_to_target(%Commission{} = r),
    do: target_link("#{r.user.name}'s commission page", ~p"/profiles/#{r.user}/commission")

  def link_to_target(%Gallery{} = r), do: target_link("Gallery '#{r.title}'", ~p"/galleries/#{r}")

  def link_to_target(%Post{} = r),
    do:
      target_link(
        "Post in #{r.topic.title}",
        ~p"/forums/#{r.topic.forum}/topics/#{r.topic}?#{[post_id: r.id]}" <> "#post_#{r.id}"
      )

  def link_to_target(%User{} = r), do: target_link("User '#{r.name}'", ~p"/profiles/#{r}")

  def link_to_target(_target) do
    "Reported item permanently destroyed."
  end

  defp target_link(text, path), do: link(text, to: path, class: "touch-link")

  def get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua] -> ua
      _ -> ""
    end
  end
end
