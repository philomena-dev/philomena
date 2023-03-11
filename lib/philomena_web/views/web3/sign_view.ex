defmodule PhilomenaWeb.Web3SignerView do
  use PhilomenaWeb, :view

  def render("index.json", %{
    data: data
  }) do
    %{
      name: data.name,
      id: data.id,
      desc: data.desc
    }
  end


end
