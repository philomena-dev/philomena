defmodule PhilomenaWeb.RuleController do
  use PhilomenaWeb, :controller

  alias Philomena.Rules
  alias Philomena.Rules.Rule
  alias PhilomenaWeb.MarkdownRenderer

  def index(conn, _params) do
    rules =
      Rules.list_visible_rules()
      |> Enum.map(&render_rule(&1, conn))

    last_updated_at =
      rules
      |> Enum.map(& &1.updated_at)
      |> Enum.max(DateTime)

    render(conn, :index, rules: rules, last_updated_at: last_updated_at)
  end

  def new(conn, _params) do
    changeset = Rules.change_rule(%Rule{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"rule" => rule_params}) do
    case Rules.create_rule(rule_params) do
      {:ok, rule} ->
        conn
        |> put_flash(:info, "Rule created successfully.")
        |> redirect(to: ~p"/rules/#{rule}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    rule =
      id
      |> Rules.get_by_position!()
      |> render_rule(conn)

    render(conn, :show, rule: rule)
  end

  def edit(conn, %{"id" => id}) do
    rule = Rules.get_rule!(id)
    changeset = Rules.change_rule(rule)
    render(conn, :edit, rule: rule, changeset: changeset)
  end

  def update(conn, %{"id" => id, "rule" => rule_params}) do
    rule = Rules.get_rule!(id)

    case Rules.update_rule(rule, rule_params) do
      {:ok, rule} ->
        conn
        |> put_flash(:info, "Rule updated successfully.")
        |> redirect(to: ~p"/rules/#{rule}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, rule: rule, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    rule = Rules.get_rule!(id)
    {:ok, _rule} = Rules.delete_rule(rule)

    conn
    |> put_flash(:info, "Rule deleted successfully.")
    |> redirect(to: ~p"/rules")
  end

  defp render_rule(rule, conn) do
    %{
      rule
      | description:
          if(rule.description != "",
            do: MarkdownRenderer.render_unsafe(rule.description, conn),
            else: ""
          ),
        example:
          if(rule.example != "",
            do: MarkdownRenderer.render_unsafe(rule.example, conn),
            else: ""
          )
    }
  end
end
