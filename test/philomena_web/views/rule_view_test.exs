defmodule PhilomenaWeb.RuleViewTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.RuleView

  test "a rule only staff see is a warning card, even when highlighted" do
    assert RuleView.rule_class(%{hidden: true, internal: false, highlight: true}) ==
             "card-warning"

    assert RuleView.rule_class(%{hidden: false, internal: true, highlight: false}) ==
             "card-warning"
  end

  test "a highlighted public rule is a danger card, any other a plain card" do
    assert RuleView.rule_class(%{hidden: false, internal: false, highlight: true}) ==
             "card-danger"

    assert RuleView.rule_class(%{hidden: false, internal: false, highlight: false}) == nil
  end
end
