defmodule Philomena.Schema.Approval do
  import Ecto.Changeset

  alias Philomena.Markdown

  defp relative_link?(%URI{scheme: nil, host: nil}), do: true
  defp relative_link?(%URI{}), do: false

  defp site_domains do
    String.split(Application.get_env(:philomena, :site_domains), ",") ++
      [Application.get_env(:philomena, :cdn_host)]
  end

  defp trusted_link?(trusted_domains, link) do
    uri = URI.parse(link)
    host = uri.host && String.downcase(uri.host)

    relative_link?(uri) or host in trusted_domains
  end

  defp automatic_approval?(body, :image_embeds) do
    not Markdown.has_image?(body)
  end

  defp automatic_approval?(body, :external_links) do
    domains = site_domains()

    body
    |> Markdown.links()
    |> Enum.all?(&trusted_link?(domains, &1))
  end

  def trusted?(nil), do: false
  def trusted?(user) when user.role != "user", do: true
  def trusted?(user) when user.verified, do: true

  def trusted?(user) do
    DateTime.diff(DateTime.utc_now(), user.created_at, :day) > 14
  end

  def approved?(_user, nil, _check), do: true
  def approved?(_user, "", _check), do: true

  def approved?(user, body, check) do
    trusted?(user) or automatic_approval?(body, check)
  end

  def maybe_put_approval(
        %{changes: %{body: body}, valid?: true} = changeset,
        user,
        check
      ) do
    was_approved? = fetch_field!(changeset, :approved)
    approved? = approved?(user, body, check)

    change(
      changeset,
      approved: approved?,
      became_unapproved?: was_approved? and not approved?
    )
  end

  def maybe_put_approval(changeset, _user, _check), do: changeset

  def approve_changeset(changeset) do
    if get_field(changeset, :approved) do
      add_error(changeset, :approved, "is already approved")
    else
      change(changeset, approved: true)
    end
  end
end
