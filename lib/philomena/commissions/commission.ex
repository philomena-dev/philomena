defmodule Philomena.Commissions.Commission do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Commissions.Item
  alias Philomena.Images.Image
  alias Philomena.Users.User

  schema "commissions" do
    belongs_to :user, User
    belongs_to :sheet_image, Image
    has_many :items, Item

    field :open, :boolean
    field :information, :string, default: ""
    field :contact, :string, default: ""
    field :will_create, :string, default: ""
    field :will_not_create, :string, default: ""
    field :commission_items_count, :integer, default: 0
    field :accepting_requests, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(commission, attrs) do
    commission
    |> cast(attrs, [
      :information,
      :contact,
      :will_create,
      :will_not_create,
      :open,
      :sheet_image_id
    ])
    |> validate_required([:user_id, :information, :contact, :open])
    |> validate_length(:information, max: 1000, count: :bytes)
    |> validate_length(:contact, max: 1000, count: :bytes)
    |> validate_length(:will_create, max: 1000, count: :bytes)
    |> validate_length(:will_not_create, max: 1000, count: :bytes)
  end

  def suggested_tags do
    [
      "safe",
      "suggestive",
      "questionable",
      "explicit",
      "anthro",
      "feral",
      "human",
      "humanoid",
      "oc",
      "original species",
      "shipping",
      "comic",
      "gore",
      "violence",
      "fetish",
      "my little pony",
      "fanart"
    ]
  end
end
