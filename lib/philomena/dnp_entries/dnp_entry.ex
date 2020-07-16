defmodule Philomena.DnpEntries.DnpEntry do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Tags.Tag
  alias Philomena.Users.User

  schema "dnp_entries" do
    belongs_to :requesting_user, User
    belongs_to :modifying_user, User
    belongs_to :tag, Tag

    field :aasm_state, :string, default: "requested"
    field :dnp_type, :string, default: ""
    field :conditions, :string, default: ""
    field :reason, :string, default: ""
    field :hide_reason, :boolean, default: false
    field :instructions, :string, default: ""
    field :feedback, :string, default: ""

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(dnp_entry, attrs) do
    dnp_entry
    |> cast(attrs, [])
    |> validate_required([])
  end

  def update_changeset(dnp_entry, attrs, tag) do
    dnp_entry
    |> cast(attrs, [:conditions, :reason, :hide_reason, :instructions, :feedback, :dnp_type])
    |> put_change(:tag_id, tag.id)
    |> validate_required([:reason, :dnp_type])
    |> validate_inclusion(:dnp_type, types())
    |> validate_conditions()
    |> foreign_key_constraint(:tag_id, name: "fk_rails_473a736b4a")
  end

  def creation_changeset(dnp_entry, attrs, tag, user) do
    dnp_entry
    |> change(requesting_user_id: user.id)
    |> update_changeset(attrs, tag)
  end

  def transition_changeset(dnp_entry, user, new_state) do
    dnp_entry
    |> change(modifying_user_id: user.id)
    |> change(aasm_state: new_state)
    |> validate_inclusion(:aasm_state, states())
  end

  defp validate_conditions(%Ecto.Changeset{changes: %{dnp_type: "Other"}} = changeset),
    do: validate_required(changeset, [:conditions])

  defp validate_conditions(changeset),
    do: changeset

  def types do
    reasons()
    |> Enum.map(fn {title, _desc} -> title end)
  end

  def reasons do
    [
      {"Uploader Credit Change", "I would like the uploader credit for existing and future uploads of my art to be assigned to me."},
      {"Artist Upload Only", "I am an artist and will be uploading my own art."},
      {"With Permission Only", "I am an artist and have given specific people permission to upload my art."},
      {"Delayed Artist Upload Only", "I am an artist and will be uploading my own art. After a default of 6 months, users can post my art."},
      {"Delayed With Permission Only", "I am an artist and have given specific people permission to upload my art. After a default of 6 months, users can post my art."},
      {"Limited Edits", "I am an artist and would like to limit edits to things likely to fall under Fair Use (Parody, Transformative, Sufficiently different from original.)"},
      {"Separate Edits", "I am an artist and would like edits to be placed under a different artist tag."},
      {"User Interaction Lock", "I am an artist and would like my art to have comments disabled."},
      {"Video Hold", "I am a content creator and would like to delay my videos from being uploaded to Ponybooru."},
      {"Image Hold", "I am an artist and would like to delay my art from being uploaded to Ponybooru."},
      {"Artist Tag Change", "I would like my artist tag to be changed to something that can not be connected to my current name."},
      {"Hidden by default", "I would like my art to be available to logged in users only."},
      {"Other", "Choose this if you would like to choose a combination of other DNP types."}
    ]
  end

  def states do
    [
      "requested",
      "claimed",
      "listed",
      "rescinded",
      "acknowledged",
      "closed"
    ]
  end
end
