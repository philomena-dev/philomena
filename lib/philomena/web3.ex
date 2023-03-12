defmodule Philomena.Web3 do

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Users.{User}
  alias Philomena.Roles.Role

  defp clean_roles(nil), do: []
  defp clean_roles(roles), do: Enum.filter(roles, &("" != &1))

  def change_address(%User{} = user) do
    User.changeset(user, %{})
  end

  def update_address(%User{} = user, attrs) do
    roles =
      Role
      |> where([r], r.id in ^clean_roles(attrs["roles"]))
      |> Repo.all()

    changeset =
      user
      |> User.update_changeset(attrs, roles)

    Multi.new()
    |> Multi.update(:user, changeset)
    |> Multi.run(:unsubscribe, fn _repo, %{user: user} ->
      unsubscribe_restricted_actors(user)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  defp unsubscribe_restricted_actors(%User{} = user) do
    forum_ids =
      Forum
      |> order_by(asc: :name)
      |> Repo.all()
      |> Enum.reject(&Canada.Can.can?(user, :show, &1))
      |> Enum.map(& &1.id)

    {_count, nil} =
      Forums.Subscription
      |> where([s], s.user_id == ^user.id and s.forum_id in ^forum_ids)
      |> Repo.delete_all()

    {_count, nil} =
      Topics.Subscription
      |> join(:inner, [s], _ in assoc(s, :topic))
      |> where([s, t], s.user_id == ^user.id and t.forum_id in ^forum_ids)
      |> Repo.delete_all()

    {:ok, nil}
  end

end
