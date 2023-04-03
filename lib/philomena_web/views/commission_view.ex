defmodule PhilomenaWeb.CommissionView do
  use PhilomenaWeb, :view

  alias Philomena.Commissions.Commission
  alias PhilomenaWeb.Web3Cfg

  def categories, do: [[key: "-", value: ""] | Commission.categories()]
  def types, do: Commission.types()
  def currencies, do: Web3Cfg.currenciesSearch()
  def currencies_type, do: Web3Cfg.currenciesType()
  def web3Cfg, do: Web3Cfg.get()
end
