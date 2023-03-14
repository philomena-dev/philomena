defmodule Philomena.EthereumChanges.EthereumChange do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "ethereum_changes" do
    belongs_to :user, User
    field :ethereum, :string
    field :sign_data, :string

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(ethereum_change, old_ethereum) do
    ethereum_change
    |> change(ethereum: old_ethereum)
    |> validate_required([])
  end

  def changeset2(ethereum_change, old_ethereum, sign_msg, sign_data) do
    ethereum_change
    |> change(ethereum: old_ethereum)
    |> change(sign_data: "{text: '#{sign_msg}', sign: '#{sign_data}'}" )
    |> validate_required([])
  end
end
