defmodule PhilomenaWeb.RuleController do
  use PhilomenaWeb, :controller

  alias Philomena.Rules
  alias Philomena.Rules.Rule
  alias PhilomenaWeb.MarkdownRenderer

  plug :load_and_authorize_resource,
    model: Rule,
    id_field: "position",
    except: [:index]

  plug :check_permission when action in [:show]

  def index(conn, _params) do
    rules =
      if Canada.Can.can?(conn.assigns.current_user, :edit, Rule) do
        Rules.list_rules()
      else
        Rules.list_visible_rules()
      end
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
    case Rules.create_rule_with_version(rule_params, conn.assigns.current_user) do
      {:ok, [rule, _version]} ->
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

    versions =
      rule
      |> Rules.list_rule_versions()
      |> generate_diff()

    render(conn, :show, rule: rule, versions: versions)
  end

  def edit(conn, %{"id" => id}) do
    rule = Rules.get_by_position!(id)
    changeset = Rules.change_rule(rule)
    render(conn, :edit, rule: rule, changeset: changeset)
  end

  def update(conn, %{"id" => id, "rule" => rule_params}) do
    rule = Rules.get_by_position!(id)

    case Rules.update_rule_with_version(rule, conn.assigns.current_user, rule_params) do
      {:ok, [rule, _version]} ->
        conn
        |> put_flash(:info, "Rule updated successfully.")
        |> redirect(to: ~p"/rules/#{rule}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, rule: rule, changeset: changeset)
    end
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

  defp diff_field(field, previous, next) do
    old = Map.get(previous, field)
    new = Map.get(next, field)

    if old == new do
      nil
    else
      List.myers_difference(split(old), split(new))
    end
  end

  defp compare_versions(previous, next) do
    %{
      description: diff_field(:description, previous, next),
      example: diff_field(:example, previous, next)
    }
  end

  defp split(nil), do: ""
  defp split(body), do: String.split(body, "\n")

  defp generate_diff(versions) when length(versions) < 2 do
    []
  end

  defp generate_diff(versions) do
    versions
    # Reverse to have oldest first
    |> Enum.reverse()
    |> Enum.map_reduce(nil, fn version, previous ->
      diffs =
        if previous do
          compare_versions(previous, version)
        else
          %{
            description: nil,
            example: nil
          }
        end

      {%{version | differences: diffs, previous: previous}, version}
    end)
    |> elem(0)
    # Reverse back to have newest first
    |> Enum.reverse()
  end

  defp check_permission(conn, _opts) do
    id = conn.params["id"]
    rule = Rules.get_by_position!(id)

    if rule.hidden or rule.internal do
      if Canada.Can.can?(conn.assigns.current_user, :edit, rule) do
        conn
      else
        conn
        |> put_flash(:error, "You do not have permission to view that rule.")
        |> redirect(to: ~p"/rules")
        |> halt()
      end
    else
      conn
    end
  end
end
