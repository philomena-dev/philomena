defmodule Philomena.Web3 do

  import Ecto.Query, warn: false
  alias Philomena.Repo
  alias Philomena.Users.{User}
  alias Philomena.EthereumChanges.EthereumChange
  alias Philomena.EthereumRenameWorker

  alias PhilomenaWeb.Web3SignerData
  import ExWeb3EcRecover

  def change_address(%User{} = user) do
    EthereumChange.changeset(user, %{})
  end

  def update_address(%User{} = user, user_params) do
    old_ethereum = user.ethereum

    sign_msg = Web3SignerData.get(user)
    signature_address = ExWeb3EcRecover.recover_personal_signature(sign_msg.desc, user_params["sign_data"])

    if String.downcase(signature_address) == user_params["ethereum"] do

      ethereum_change = EthereumChange.changeset2(%EthereumChange{user_id: user.id}, user.ethereum, sign_msg.desc, user_params["sign_data"])
      account = User.ethereum_changeset(user, user_params)

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

    else
      {:error, %{}}
    end

  end

end
