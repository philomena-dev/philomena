defmodule PhilomenaWeb.CommunicationView do
  use PhilomenaWeb, :view

  alias Philomena.Attribution
  alias Philomena.Attribution.AnonymousName
  alias Philomena.Comments.Comment
  alias Philomena.Posts.Post

  @doc "What a comment or post is called in its text, ids and form parameters."
  def noun(%Comment{}), do: :comment
  def noun(%Post{}), do: :post

  @doc "The path of an action on a comment or post, or with `:link` its place on the image or topic page."
  def communication_path(%Comment{} = c, :link),
    do: ~p"/images/#{c.image_id}" <> "#comment_#{c.id}"

  def communication_path(%Comment{} = c, :report),
    do: ~p"/images/#{c.image_id}/comments/#{c}/reports/new"

  def communication_path(%Comment{} = c, :approve),
    do: ~p"/images/#{c.image_id}/comments/#{c}/approve"

  def communication_path(%Comment{} = c, :hide), do: ~p"/images/#{c.image_id}/comments/#{c}/hide"

  def communication_path(%Comment{} = c, :delete),
    do: ~p"/images/#{c.image_id}/comments/#{c}/delete"

  def communication_path(%Comment{} = c, :history),
    do: ~p"/images/#{c.image_id}/comments/#{c}/history"

  def communication_path(%Comment{} = c, :edit), do: ~p"/images/#{c.image_id}/comments/#{c}/edit"

  def communication_path(%Post{topic: t} = p, :link),
    do: ~p"/forums/#{t.forum}/topics/#{t}?#{[post_id: p.id]}" <> "#post_#{p.id}"

  def communication_path(%Post{topic: t} = p, :report),
    do: ~p"/forums/#{t.forum}/topics/#{t}/posts/#{p}/reports/new"

  def communication_path(%Post{topic: t} = p, :approve),
    do: ~p"/forums/#{t.forum}/topics/#{t}/posts/#{p}/approve"

  def communication_path(%Post{topic: t} = p, :hide),
    do: ~p"/forums/#{t.forum}/topics/#{t}/posts/#{p}/hide"

  def communication_path(%Post{topic: t} = p, :delete),
    do: ~p"/forums/#{t.forum}/topics/#{t}/posts/#{p}/delete"

  def communication_path(%Post{topic: t} = p, :history),
    do: ~p"/forums/#{t.forum}/topics/#{t}/posts/#{p}/history"

  def communication_path(%Post{topic: t} = p, :edit),
    do: ~p"/forums/#{t.forum}/topics/#{t}/posts/#{p}/edit"

  def markdown_safe_author(object) do
    Philomena.Markdown.escape("@" <> author_name(object))
  end

  defp author_name(object) do
    if Attribution.anonymous?(object) || !object.user do
      AnonymousName.generate(object)
    else
      object.user.name
    end
  end
end
