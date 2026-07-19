defmodule Philomena.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Rules.Rule
  alias Philomena.Images.Image
  alias Philomena.Comments.Comment
  alias Philomena.Posts.Post
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Galleries.Gallery

  # Maps each target column to its legacy `reportable_type`
  # string. Exactly one of these columns is set on a live report; all are
  # NULL on an orphaned report whose target was deleted.
  @associations [
    {:image_id, :image, "Image"},
    {:comment_id, :comment, "Comment"},
    {:post_id, :post, "Post"},
    {:reported_user_id, :reported_user, "User"},
    {:commission_id, :commission, "Commission"},
    {:conversation_id, :conversation, "Conversation"},
    {:gallery_id, :gallery, "Gallery"}
  ]

  schema "reports" do
    belongs_to :user, User
    belongs_to :admin, User
    belongs_to :rule, Rule, on_replace: :nilify

    belongs_to :image, Image
    belongs_to :comment, Comment
    belongs_to :post, Post
    belongs_to :reported_user, User
    belongs_to :commission, Commission
    belongs_to :conversation, Conversation
    belongs_to :gallery, Gallery

    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :reason, :string
    field :state, :string, default: "open"
    field :open, :boolean, default: true
    field :system, :boolean, default: false

    field :reportable, :any, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc """
  The list of foreign key columns, one per reportable type.
  """
  def reportable_columns, do: Enum.map(@associations, fn {column, _assoc, _type} -> column end)

  def column_for_type(type) do
    Enum.find_value(@associations, fn
      {column, _assoc, ^type} -> column
      _ -> nil
    end)
  end

  @doc """
  Preloads to apply to the associations so downstream views and the
  search index have the nested data they expect.
  """
  def reportable_preloads do
    [
      :reported_user,
      image: [:user, :sources, tags: :aliases],
      comment: [:user, image: [:sources, tags: :aliases]],
      post: [:user, topic: :forum],
      commission: [:user],
      conversation: [:from, :to],
      gallery: [:user]
    ]
  end

  @doc """
  The legacy reportable type string for a report, or `nil` when the report is
  orphaned (its target was deleted).
  """
  def reportable_type(%__MODULE__{} = report) do
    Enum.find_value(@associations, fn {column, _assoc, type} ->
      if Map.get(report, column), do: type
    end)
  end

  @doc """
  The id of the reported target, or `nil` when the report is orphaned.
  """
  def reportable_id(%__MODULE__{} = report) do
    Enum.find_value(@associations, fn {column, _assoc, _type} -> Map.get(report, column) end)
  end

  @doc """
  The preloaded reportable target struct, or `nil` when the report is orphaned.
  """
  def reportable(%__MODULE__{} = report) do
    Enum.find_value(@associations, fn {column, assoc, _type} ->
      if Map.get(report, column), do: Map.get(report, assoc)
    end)
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
      :reason,
      :ip,
      :fingerprint,
      :user_agent
    ])
    |> validate_reportable()
  end

  def user_creation_changeset(report, attrs, attribution, rule) do
    report
    |> creation_changeset(attrs, attribution, rule)
    |> validate_rule()
  end

  # A report must reference exactly one target on creation.
  defp validate_reportable(changeset) do
    set = Enum.count(reportable_columns(), &(not is_nil(get_field(changeset, &1))))

    if set == 1 do
      changeset
    else
      add_error(changeset, :reportable, "must reference exactly one target")
    end
  end

  defp validate_rule(changeset) do
    case get_assoc(changeset, :rule, :struct) do
      nil -> add_error(changeset, :rule_id, "is invalid")
      %Rule{internal: true} -> add_error(changeset, :rule_id, "is internal")
      _ -> changeset
    end
  end
end
