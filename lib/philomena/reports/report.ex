defmodule Philomena.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Rules.Rule

  schema "reports" do
    belongs_to :user, User
    belongs_to :admin, User
    belongs_to :rule, Rule, on_replace: :nilify

    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :reason, :string
    field :state, :string, default: "open"
    field :open, :boolean, default: true
    field :system, :boolean, default: false

    # fixme: rails polymorphic relation
    field :reportable_id, :integer
    field :reportable_type, :string

    field :reportable, :any, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(report, attrs) do
    report
    |> cast(attrs, [])
    |> validate_required([])
  end

  def conversion_changeset(report, attrs, rule) do
    report
    |> cast(attrs, [:reason])
    |> put_assoc(:rule, rule)
    |> validate_required([:reason])
  end

  # Ensure that the report is not currently claimed before
  # attempting to claim
  def claim_changeset(report, user) do
    change(report)
    |> validate_inclusion(:admin_id, [])
    |> put_change(:admin_id, user.id)
    |> put_change(:open, true)
    |> put_change(:state, "in_progress")
  end

  def unclaim_changeset(report) do
    change(report)
    |> put_change(:admin_id, nil)
    |> put_change(:open, true)
    |> put_change(:state, "open")
  end

  def close_changeset(report, user) do
    change(report)
    |> put_change(:admin_id, user.id)
    |> put_change(:open, false)
    |> put_change(:state, "closed")
  end

  @doc false
  def creation_changeset(report, attrs, attribution, rule) do
    report
    |> cast(attrs, [:reason, :user_agent])
    |> put_assoc(:rule, rule)
    |> validate_length(:reason, max: 10_000, count: :bytes)
    |> validate_length(:user_agent, max: 1000, count: :bytes)
    |> change(attribution)
    |> validate_required([
      :reportable_id,
      :reportable_type,
      :reason,
      :ip,
      :fingerprint,
      :user_agent
    ])
  end

  def user_creation_changeset(report, attrs, attribution, rule) do
    report
    |> creation_changeset(attrs, attribution, rule)
    |> validate_rule()
  end

  defp validate_rule(changeset) do
    case get_assoc(changeset, :rule, :struct) do
      nil -> add_error(changeset, :rule_id, "is invalid")
      %Rule{internal: true} -> add_error(changeset, :rule_id, "is internal")
      _ -> changeset
    end
  end
end
