defmodule Philomena.RulesTest do
  use Philomena.DataCase

  alias Philomena.Rules
  alias Philomena.Users.User

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

    test "find_rule/1 returns the rule with given id" do
      rule = rule_fixture()
      assert Rules.find_rule(rule.id) == rule
    end

    test "create_rule_with_version/1 with valid data creates a rule" do
      valid_attrs = %{
        name: "some name",
        position: 42,
        description: "some description",
        short_description: "some short_description",
        example: "some example",
        highlight: true
      }

      assert {:ok, %Rule{} = rule} = Rules.create_rule_with_version(valid_attrs, %User{id: 1})
      assert rule.name == "some name"
      assert rule.position == 42
      assert rule.description == "some description"
      assert rule.short_description == "some short_description"
      assert rule.example == "some example"
      assert rule.highlight == true
    end

    test "create_rule_with_version/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Rules.create_rule_with_version(@invalid_attrs, %User{id: 1})
    end

    test "update_rule_with_version/2 with valid data updates the rule" do
      rule = rule_fixture()

      update_attrs = %{
        name: "some updated name",
        position: 43,
        description: "some updated description",
        short_description: "some updated short_description",
        example: "some updated example",
        highlight: false
      }

      assert {:ok, %Rule{} = rule} =
               Rules.update_rule_with_version(rule, update_attrs, %User{id: 1})

      assert rule.name == "some updated name"
      assert rule.position == 43
      assert rule.description == "some updated description"
      assert rule.short_description == "some updated short_description"
      assert rule.example == "some updated example"
      assert rule.highlight == false
    end

    test "update_rule_with_version/2 with invalid data returns error changeset" do
      rule = rule_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Rules.update_rule_with_version(rule, @invalid_attrs, %User{id: 1})

      assert rule == Rules.find_rule(rule.id)
    end

    test "change_rule/1 returns a rule changeset" do
      rule = rule_fixture()
      assert %Ecto.Changeset{} = Rules.change_rule(rule)
    end
  end
end
