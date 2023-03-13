defmodule Philomena.EthereumRenameWorker do
  alias Philomena.Users

  def perform(old_ethereum, new_ethereum) do
    Users.perform_ethereum_rename(old_ethereum, new_ethereum)
  end
end
