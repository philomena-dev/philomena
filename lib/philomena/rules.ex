defmodule Philomena.Rules do
  @moduledoc """
  The Rules context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Rules.Rule
  alias Philomena.Rules.RuleVersion
  alias Philomena.Users.User

  @doc """
  Returns the list of rules.

  ## Examples

      iex> list_rules()
      [%Rule{}, ...]

  """
  def list_rules do
    Repo.all(from r in Rule, order_by: [asc: r.position])
  end

  @doc """
  Returns the list of visible rules.

  ## Examples

      iex> list_visible_rules()
      [%Rule{}, ...]
  """
  def list_visible_rules do
    Repo.all(
      from r in Rule,
        where: r.hidden == false and r.internal == false,
        order_by: [asc: r.position]
    )
  end

  @doc """
  Returns a list of all the reportable rules.

  ## Examples

      iex> list_reportable_rules()
      [%Rule{name: "Rule #0", ...}, ...]

  """
  def list_reportable_rules do
    Repo.all(
      from r in Rule,
        where: r.internal == false,
        order_by: [asc: r.position]
    )
  end

  @doc """
  Gets a single rule. Returns nil if the rule does not exist.

  ## Examples

      iex> find_rule(123)
      %Rule{}

      iex> find_rule(456)
      nil

  """
  def find_rule(id), do: Repo.get(Rule, id)

  @doc """
  Gets a single rule by its position.

  Raises `Ecto.NoResultsError` if the Rule does not exist.

  ## Examples

      iex> get_by_position!(0)
      %Rule{name: "Rule #0", position: 0, ...}

      iex> get_by_position!(99999)
      ** (Ecto.NoResultsError)

  """
  def get_by_position!(position), do: Repo.get_by!(Rule, position: position)

  @doc """
  Gets a single rule by its name.

  Raises `Ecto.NoResultsError` if the Rule does not exist.

  ## Examples

      iex> get_by_name!("Rule #0")
      %Rule{name: "Rule #0", ...}

      iex> get_by_name!("Nonexistent Rule")
      ** (Ecto.NoResultsError)

  """
  def get_by_name!(name), do: Repo.get_by!(Rule, name: name)

  @doc """
  Returns a list of all rule versions for a given rule.

  ## Examples

      iex> list_rule_versions(rule)
      [%RuleVersion{...}, ...]

  """
  def list_rule_versions(%Rule{} = rule) do
    Repo.all(
      from rv in RuleVersion,
        where: rv.rule_id == ^rule.id,
        order_by: [desc: rv.created_at],
        preload: [:user]
    )
  end

  defp create_rule_version(%Rule{} = rule, %User{} = user) do
    %RuleVersion{}
    |> RuleVersion.changeset(%{
      name: rule.name,
      title: rule.title,
      description: rule.description,
      short_description: rule.short_description,
      example: rule.example,
      rule_id: rule.id,
      user_id: user.id
    })
    |> Repo.insert()
  end

  defp create_rule_version(%Rule{} = rule, nil) do
    create_rule_version(rule, %User{id: nil})
  end

  defp create_rule(attrs) do
    %Rule{}
    |> Rule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a rule and stores the initial version attributed to a user.

  If the user is nil, then it is assumed to be a system action.

  ## Examples

      iex> create_rule_with_version(%{name: "Rule #0", ...}, user)
      {:ok, [%Rule{}, %RuleVersion{}]}

      iex> create_rule_with_version(%{bad_field: bad_value, ...}, user)
      {:error, %Ecto.Changeset{}}

  """
  def create_rule_with_version(attrs, user) do
    Repo.transact(fn ->
      with {:ok, rule} <- create_rule(attrs),
           {:ok, rule_version} <- create_rule_version(rule, user) do
        {:ok, [rule, rule_version]}
      end
    end)
  end

  defp update_rule(%Rule{} = rule, attrs) do
    rule
    |> Rule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a rule and stores the new version attributed to a user.

  If the user is nil, then it is assumed to be a system edit.

  ## Examples

      iex> update_rule_with_version(rule, user, %{field: new_value})
      {:ok, [%Rule{}, %RuleVersion{}]}

      iex> update_rule_with_version(rule, user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule_with_version(%Rule{} = rule, user, attrs) do
    Repo.transact(fn ->
      with {:ok, updated_rule} <- update_rule(rule, attrs),
           {:ok, rule_version} <- create_rule_version(updated_rule, user) do
        {:ok, [updated_rule, rule_version]}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rule changes.

  ## Examples

      iex> change_rule(rule)
      %Ecto.Changeset{data: %Rule{}}

  """
  def change_rule(%Rule{} = rule, attrs \\ %{}) do
    Rule.changeset(rule, attrs)
  end
end
