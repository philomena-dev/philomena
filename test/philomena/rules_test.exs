defmodule Philomena.RulesTest do
  use Philomena.DataCase

  alias Philomena.Rules

  describe "rules" do
    alias Philomena.Rules.Rule

    import Philomena.RulesFixtures

    @invalid_attrs %{
      name: nil,
      position: nil,
      description: nil,
      short_description: nil,
      example: nil,
      highlight: nil
    }

    test "list_rules/0 returns all rules" do
      rule = rule_fixture()
      assert Rules.list_rules() == [rule]
    end

    test "get_rule!/1 returns the rule with given id" do
      rule = rule_fixture()
      assert Rules.get_rule!(rule.id) == rule
    end

    test "create_rule/1 with valid data creates a rule" do
      valid_attrs = %{
        name: "some name",
        position: 42,
        description: "some description",
        short_description: "some short_description",
        example: "some example",
        highlight: true
      }

      assert {:ok, %Rule{} = rule} = Rules.create_rule(valid_attrs)
      assert rule.name == "some name"
      assert rule.position == 42
      assert rule.description == "some description"
      assert rule.short_description == "some short_description"
      assert rule.example == "some example"
      assert rule.highlight == true
    end

    test "create_rule/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rules.create_rule(@invalid_attrs)
    end

    test "update_rule/2 with valid data updates the rule" do
      rule = rule_fixture()

      update_attrs = %{
        name: "some updated name",
        position: 43,
        description: "some updated description",
        short_description: "some updated short_description",
        example: "some updated example",
        highlight: false
      }

      assert {:ok, %Rule{} = rule} = Rules.update_rule(rule, update_attrs)
      assert rule.name == "some updated name"
      assert rule.position == 43
      assert rule.description == "some updated description"
      assert rule.short_description == "some updated short_description"
      assert rule.example == "some updated example"
      assert rule.highlight == false
    end

    test "update_rule/2 with invalid data returns error changeset" do
      rule = rule_fixture()
      assert {:error, %Ecto.Changeset{}} = Rules.update_rule(rule, @invalid_attrs)
      assert rule == Rules.get_rule!(rule.id)
    end

    test "delete_rule/1 deletes the rule" do
      rule = rule_fixture()
      assert {:ok, %Rule{}} = Rules.delete_rule(rule)
      assert_raise Ecto.NoResultsError, fn -> Rules.get_rule!(rule.id) end
    end

    test "change_rule/1 returns a rule changeset" do
      rule = rule_fixture()
      assert %Ecto.Changeset{} = Rules.change_rule(rule)
    end
  end
end
