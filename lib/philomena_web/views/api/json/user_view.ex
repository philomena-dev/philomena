defmodule PhilomenaWeb.Api.Json.UserView do
  use PhilomenaWeb, :view

  def render("show.json", %{user: user} = assigns) do
    %{user: render_one(user, PhilomenaWeb.Api.Json.UserView, "profile.json", assigns)}
  end

  def render("profile.json", %{user: user} = assigns) do
    %{
      id: user.id,
      ethereum: if(user.ethereum != "", do: user.ethereum),
      name: user.name,
      slug: user.slug,
      role: role(user),
      avatar_url: avatar_url(user),
      created_at: user.created_at
    }
  end

  defp role(%{hide_default_role: true}) do
    "user"
  end

  defp role(user) do
    user.role
  end

  defp avatar_url(%{avatar: nil}) do
    nil
  end

  defp avatar_url(user) do
    Application.get_env(:philomena, :avatar_url_root) <> "/" <> user.avatar
  end
end
