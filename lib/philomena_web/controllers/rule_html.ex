defmodule PhilomenaWeb.RuleHTML do
  use PhilomenaWeb, :html

  embed_templates "rule_html/*"

  @doc """
  Renders a rule form.

  The form is defined in the template at
  rule_html/rule_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def rule_form(assigns)
end
