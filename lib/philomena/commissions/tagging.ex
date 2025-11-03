defmodule Philomena.Commissions.Tagging do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Commissions.Commission
  alias Philomena.Tags.Tag

  @primary_key false

  schema "commission_taggings" do
    belongs_to :commission, Commission, primary_key: true
    belongs_to :tag, Tag, primary_key: true
  end

  @doc false
  def changeset(tagging, attrs) do
    tagging
    |> cast(attrs, [])
    |> validate_required([])
  end
end
