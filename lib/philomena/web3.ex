defmodule Philomena.Web3 do

  import Ecto.Query, warn: false
  alias Philomena.Repo
  alias Philomena.Users.{User}
  alias Philomena.EthereumChanges.EthereumChange
  alias Philomena.EthereumRenameWorker

  def change_address(%User{} = user) do
    User.changeset(user, %{})
  end

  def update_address(%User{} = user, data) do
    old_ethereum = user.ethereum

    ethereum_change = EthereumChange.changeset(%EthereumChange{user_id: user.id}, user.ethereum)
    account = User.name_changeset(user, user_params)

    Multi.new()
    |> Multi.insert(:ethereum_change, ethereum_change)
    |> Multi.update(:account, account)
    |> Repo.transaction()
    |> case do
      {:ok, %{account: %{ethereum: new_ethereum} = account}} ->
        Exq.enqueue(Exq, "indexing", EthereumRenameWorker, [old_ethereum, new_ethereum])

        {:ok, account}

      {:error, :account, changeset, _changes} ->
        {:error, changeset}
    end
  end

end