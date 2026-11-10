defmodule PhilomenaWeb.RuleView do
  use PhilomenaWeb, :view

  @doc """
  The color of a rule's card: rules that only staff see are warnings, highlighted rules are dangers.
  """
  def rule_class(%{hidden: true}), do: "card-warning"
  def rule_class(%{internal: true}), do: "card-warning"
  def rule_class(%{highlight: true}), do: "card-danger"
  def rule_class(_rule), do: nil
end
