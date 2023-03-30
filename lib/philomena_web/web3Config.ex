# If you are afraid about web3 or need to make difficult decisions. Disable all settings here.
# I don't recommend you activate the NFT option unless you are ready to take on this kind of responsibility. Find more information in the repository docs before actually activating it.
defmodule PhilomenaWeb.Web3Cfg do
  use PhilomenaWeb, :controller

  def get() do
    %{

      enable_profile: true,
      enable_comissions: true,
      #enable_nft: false,

      currencies: %{
        polygon: "MATIC",
        ethereum: "ETH",
        bsc: "BNB",
        usd: "USD"
      },

      usd: %{

        dai: %{
          ethereum: "0x6b175474e89094c44da98b954eedeac495271d0f",
          polygon: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063"
        },

        usdt: %{
          ethereum: "0xdac17f958d2ee523a2206206994597c13d831ec7",
          polygon: "0xc2132d05d31c914a87c6611c10748aeb04b58e8f"
        },

        usdc: %{
          ethereum: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
          polygon: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
          bsc: "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d"
        }

      }

    }
  end

  def currenciesType do
    [
      "All USD Currencies",
      "USD Only",
      "Crypto USD Only",
    ]
  end

  def currencies do
    [
      "USD",
      "MATIC",
      "ETH",
      "BNB"
    ]
  end

end
