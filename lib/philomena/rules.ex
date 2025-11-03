defmodule Philomena.Rules do
  @moduledoc """
  The Rules context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Rules.Rule

  @doc """
  Returns the list of rules.

  ## Examples

      iex> list_rules()
      [%Rule{}, ...]

  """
  def list_rules do
    Repo.all(Rule)
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
  Gets a single rule.

  Raises `Ecto.NoResultsError` if the Rule does not exist.

  ## Examples

      iex> get_rule!(123)
      %Rule{}

      iex> get_rule!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rule!(id), do: Repo.get!(Rule, id)

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
  Gets a single rule by its name.

  ## Examples

      iex> find_by_name("Rule #0")
      %Rule{name: "Rule #0", ...}

      iex> find_by_name("Nonexistent Rule")
      nil

  """
  def find_by_name(name), do: Repo.get_by(Rule, name: name)

  @doc """
  Creates a rule.

  ## Examples

      iex> create_rule(%{field: value})
      {:ok, %Rule{}}

      iex> create_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule(attrs) do
    %Rule{}
    |> Rule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a rule.

  ## Examples

      iex> update_rule(rule, %{field: new_value})
      {:ok, %Rule{}}

      iex> update_rule(rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule(%Rule{} = rule, attrs) do
    rule
    |> Rule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a rule.

  ## Examples

      iex> delete_rule(rule)
      {:ok, %Rule{}}

      iex> delete_rule(rule)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule(%Rule{} = rule) do
    Repo.delete(rule)
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
