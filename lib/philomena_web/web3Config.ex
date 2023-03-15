# If you are afraid about web3 or need to make difficult decisions. Disable all settings here.
# I don't recommend you activate the NFT option unless you are ready to take on this kind of responsibility. Find more information in the repository docs before actually activating it.
defmodule PhilomenaWeb.Web3Cfg do
  use PhilomenaWeb, :controller

  def get() do
    %{
      enable_profile: true,
      enable_comissions: true,
      enable_nft: false
    }
  end

end
