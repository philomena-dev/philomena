defmodule Philomena.Web3 do

  import Ecto.Query, warn: false
  alias Philomena.Repo
  alias Philomena.Users.{User}

  def change_address(%User{} = user) do
    User.changeset(user, %{})
  end

  def update_address(%User{} = user, data) do

  end

end
