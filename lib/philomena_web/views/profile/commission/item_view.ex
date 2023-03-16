defmodule PhilomenaWeb.Profile.Commission.ItemView do
  use PhilomenaWeb, :view

  alias Philomena.Commissions.Commission
  alias PhilomenaWeb.Web3Cfg

  def types, do: Commission.types()
  def currencies, do: Web3Cfg.currencies()
  def currencies_type, do: Web3Cfg.currenciesType()
  def web3Cfg, do: Web3Cfg.get()
end
