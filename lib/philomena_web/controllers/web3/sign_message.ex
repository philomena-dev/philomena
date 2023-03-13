defmodule PhilomenaWeb.Web3SignerData do
  use PhilomenaWeb, :controller
  def get(user) do
    %{

      name: user.name,
      id: user.id,

      desc: "Hello Crypto Brony, welcome to Derpibooru! We need your signture to confirm your web3 identity into your account. By signing this request, you agree to all of Derpibooru's terms of use and privacy related to Web3.\n\nUsername: #{user.name}\nId: #{user.id}"

    }
  end
end
