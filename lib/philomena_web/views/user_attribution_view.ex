defmodule PhilomenaWeb.UserAttributionView do
  use PhilomenaWeb, :view

  alias Philomena.Attribution

  def anonymous?(object) do
    Attribution.anonymous?(object)
  end

  def name(object) do
    case is_nil(object.user) or anonymous?(object) do
      true -> anonymous_name(object)
      _false -> object.user.name
    end
  end

  def avatar_url(object) do
    case is_nil(object.user) or anonymous?(object) do
      true -> anonymous_avatar_url(anonymous_name(object))
      _false -> user_avatar_url(object)
    end
  end

  def anonymous_name(object, reveal_anon? \\ false) do
    salt = anonymous_name_salt()
    id = Attribution.object_identifier(object)
    user_id = Attribution.best_user_identifier(object)

    {:ok, <<key::size(16)>>} = :pbkdf2.pbkdf2(:sha256, id <> user_id, salt, 100, 2)

    hash =
      key
      |> Integer.to_string(16)
      |> String.pad_leading(4, "0")

    case not is_nil(object.user) and reveal_anon? do
      true -> "#{object.user.name} (##{hash}, hidden)"
      false -> "#{gettext("Anonymous")} ##{hash}"
    end
  end

  def anonymous_avatar(_name, class \\ "avatar--small") do
    class = Enum.join(["image-constrained", class], " ")

    content_tag :div, class: class do
      raw("<img xlink:href=\"/images/no_avatar.svg\" src=\"/images/no_avatar.svg\">")
    end
  end

  def user_avatar(object, class \\ "avatar--small")

  def user_avatar(%{user: nil} = object, class),
    do: anonymous_avatar(anonymous_name(object), class)

  def user_avatar(%{user: %{avatar: nil}} = object, class),
    do: anonymous_avatar(object.user.name, class)

  def user_avatar(%{user: %{avatar: avatar}}, class) do
    class = Enum.join(["image-constrained", class], " ")

    content_tag :div, class: class do
      img_tag(avatar_url_root() <> "/" <> avatar)
    end
  end

  def user_avatar_url(%{user: %{avatar: nil}} = object) do
    anonymous_avatar_url(object.user.name)
  end

  def user_avatar_url(%{user: %{avatar: avatar}}) do
    avatar_url_root() <> "/" <> avatar
  end

  def anonymous_avatar_url(_), do: "/images/no_avatar.svg"

  def user_icon(%{secondary_role: sr}) when sr in ["Site Developer", "Devops"],
    do: "fa-screwdriver-wrench"

  def user_icon(%{secondary_role: sr}) when sr in ["Public Relations"], do: "fa-bullhorn"
  def user_icon(%{hide_default_role: true}), do: nil
  def user_icon(%{role: role}) when role in ["admin", "moderator"], do: "fa-gavel"
  def user_icon(%{role: "assistant"}), do: "fa-handshake-angle"
  def user_icon(_), do: nil

  def user_labels(%{user: user}) do
    []
    |> personal_title(user)
    |> secondary_role(user)
    |> staff_role(user)
  end

  defp personal_title(labels, %{personal_title: t}) do
    case blank?(t) do
      true -> labels
      false -> [{"label--primary", t} | labels]
    end
  end

  defp personal_title(labels, _user), do: labels

  defp secondary_role(labels, %{secondary_role: t}) do
    case blank?(t) do
      true -> labels
      false -> [{"label--warning", t} | labels]
    end
  end

  defp secondary_role(labels, _user), do: labels

  defp staff_role(labels, %{hide_default_role: false, role: "admin", senior_staff: true}),
    do: [{"label--danger", "Head Administrator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "admin"}),
    do: [{"label--danger", "Administrator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "moderator", senior_staff: true}),
    do: [{"label--success", "Senior Moderator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "moderator"}),
    do: [{"label--success", "Moderator"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "assistant", senior_staff: true}),
    do: [{"label--special", "Senior Assistant"} | labels]

  defp staff_role(labels, %{hide_default_role: false, role: "assistant"}),
    do: [{"label--special", "Assistant"} | labels]

  defp staff_role(labels, _user),
    do: labels

  defp avatar_url_root do
    Application.get_env(:philomena, :avatar_url_root)
  end

  defp anonymous_name_salt do
    Application.get_env(:philomena, :anonymous_name_salt)
    |> to_string()
  end
end
