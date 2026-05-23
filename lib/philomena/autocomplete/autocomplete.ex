defmodule Philomena.Autocomplete.Autocomplete do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  schema "autocomplete" do
    field :file, :string
    field :uploaded_file, :string, virtual: true
    field :removed_file, :string, virtual: true
    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(autocomplete, attrs) do
    autocomplete
    |> cast(attrs, [:file, :uploaded_file, :removed_file])
    |> validate_required([:file])
  end
end
