# If you are afraid about web3 or need to make difficult decisions. Disable all settings here.
# I don't recommend you activate the NFT option unless you are ready to take on this kind of responsibility. Find more information in the repository docs before actually activating it.
defmodule PhilomenaWeb.Web3Cfg do
  use PhilomenaWeb, :controller

  def get() do
    %{

      enable_profile: true,
      enable_comissions: true

      # These features are undeveloped, please keep disabled.
      #ipfs: false,
      #enable_nft: false

    }
  end

  def currenciesType do
    [
      "Fiat and Crypto": "all",
      "USD Only": "usd_only"
    ]
  end

  def currencies do
    [
      USD: "USD",
      MATIC: "MATIC",
      ETH: "ETH",
      BNB: "BNB"
    ]
  end

  def currenciesSearch do
    [
      "All": "all",
      USD: "USD",
      MATIC: "MATIC",
      ETH: "ETH",
      BNB: "BNB"
    ]
  end

end
