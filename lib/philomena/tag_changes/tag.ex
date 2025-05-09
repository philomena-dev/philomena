defmodule Philomena.TagChanges.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "tag_change_tags" do
    belongs_to :tag_change, Philomena.TagChanges.TagChange
    belongs_to :tag, Philomena.Tags.Tag

    field :tag_name_cache, :string, default: "UNKNOWN TAG"
    field :added, :boolean
  end

  @doc false
  def changeset(tag_change, attrs) do
    tag_change
    |> cast(attrs, [])
    |> validate_required([])
  end
end
