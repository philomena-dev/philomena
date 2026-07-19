defmodule Philomena.ModNotes.ModNote do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Reports.Report
  alias Philomena.DnpEntries.DnpEntry

  # Maps each target column to its legacy `notable_type` string.
  # Exactly one of these columns is set on a live note; all are NULL on an
  # orphaned note whose target was deleted.
  @associations [
    {:user_id, :user, "User"},
    {:report_id, :report, "Report"},
    {:dnp_entry_id, :dnp_entry, "DnpEntry"}
  ]

  schema "mod_notes" do
    belongs_to :moderator, User

    belongs_to :user, User
    belongs_to :report, Report
    belongs_to :dnp_entry, DnpEntry

    field :body, :string

    field :notable, :any, virtual: true
    field :notable_type, :string, virtual: true
    field :notable_id, :integer, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc """
  The list of foreign key columns, one per notable type.
  """
  def notable_columns, do: Enum.map(@associations, fn {column, _assoc, _type} -> column end)

  def column_for_type(type) do
    Enum.find_value(@associations, fn
      {column, _assoc, ^type} -> column
      _ -> nil
    end)
  end

  @doc """
  Preloads to apply to the associations so downstream views have the
  nested data they expect. Report notables carry the preloads so
  the report target can be rendered.
  """
  def notable_preloads do
    [
      :user,
      report: [:user] ++ Report.reportable_preloads(),
      dnp_entry: [:requesting_user, :tag]
    ]
  end

  @doc """
  The legacy notable type string for a note, or `nil` when the note is
  orphaned (its target was deleted).
  """
  def notable_type(%__MODULE__{} = mod_note) do
    Enum.find_value(@associations, fn {column, _assoc, type} ->
      if Map.get(mod_note, column), do: type
    end)
  end

  @doc """
  The id of the notable target, or `nil` when the note is orphaned.
  """
  def notable_id(%__MODULE__{} = mod_note) do
    Enum.find_value(@associations, fn {column, _assoc, _type} -> Map.get(mod_note, column) end)
  end

  @doc """
  The preloaded notable target struct, or `nil` when the note is orphaned.
  """
  def notable(%__MODULE__{} = mod_note) do
    Enum.find_value(@associations, fn {column, assoc, _type} ->
      if Map.get(mod_note, column), do: Map.get(mod_note, assoc)
    end)
  end

  @doc false
  def changeset(mod_note, attrs) do
    mod_note
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end

  @doc false
  def creation_changeset(mod_note, attrs) do
    mod_note
    |> cast(attrs, [:notable_type, :notable_id, :body])
    |> validate_required([:notable_type, :notable_id, :body])
    |> validate_inclusion(:notable_type, ["User", "Report", "DnpEntry"])
    |> put_notable()
    |> validate_notable()
  end

  # Map the posted `notable_type`/`notable_id` pair onto its column.
  defp put_notable(changeset) do
    type = get_field(changeset, :notable_type)
    id = get_field(changeset, :notable_id)

    case column_for_type(type) do
      nil -> changeset
      column -> put_change(changeset, column, id)
    end
  end

  # A note must reference exactly one target on creation.
  defp validate_notable(changeset) do
    set = Enum.count(notable_columns(), &(not is_nil(get_field(changeset, &1))))

    if set == 1 do
      changeset
    else
      add_error(changeset, :notable, "must reference exactly one target")
    end
  end
end
