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
    field :categories, {:array, :string}, default: []
    field :information, :string, default: ""
    field :contact, :string, default: ""
    field :will_create, :string, default: ""
    field :will_not_create, :string, default: ""
    field :commission_items_count, :integer, default: 0

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
      :sheet_image_id,
      :categories
    ])
    |> drop_blank_categories()
    |> validate_required([:user_id, :information, :contact, :open])
    |> validate_length(:information, max: 1000, count: :bytes)
    |> validate_length(:contact, max: 1000, count: :bytes)
    |> validate_length(:will_create, max: 1000, count: :bytes)
    |> validate_length(:will_not_create, max: 1000, count: :bytes)
    |> validate_subset(:categories, Keyword.values(categories()))
  end

  defp drop_blank_categories(changeset) do
    categories =
      changeset
      |> get_field(:categories)
      |> Enum.filter(&(&1 not in [nil, ""]))

    change(changeset, categories: categories)
  end

  def categories do
    [
      Abgerny: "Abgerny",
      Anthro and Furry: "Anthro and Furry",
      Chikn Nuggit: "Chikn Nuggit",
      Comics: "Comics",
      Cookie Run: "Cookie Run",
      Cool as Ice Incredibox: "Cool as Ice Incredibox",
      Cyberchase: "Cyberchase",
      Dandy's World: "Dandy's World",
      Eddsworld: "Eddsworld",
      Flavor Frenzy: "Flavor Frenzy",
      Forsaken: "Forsaken",
      Friday Night Funkin': "Friday Night Funkin'",
      Fundamental Paper Education: "Fundamental Paper Education",
      "Gore, Grimdark, and Violence": "Gore, Grimdark, and Violence",
      Hazbin Hotel and Helluva Boss: "Hazbin Hotel and Helluva Boss",
      Happy Tree Friends: "Happy Tree Friends",
      "Human and Humanoid": "Human and Humanoid",
      Indigo Park: "Indigo Park",
      "Kink and Fetish": "Kink and Fetish",
      KPop Demon Hunters: "KPop Demon Hunters",
      Learning with Pibby: "Learning with Pibby",
      Murder Drones: "Murder Drones",
      My Singing Monsters: "My Singing Monsters",
      NSFW and 18+: "NSFW and 18+",
      "OCs": "OCs",
      "Original Species": "Original Species",
      Pizza Tower: "Pizza Tower",
      Plants vs. Zombies: "Plants vs. Zombies",
      Poppy Playtime: "Poppy Playtime",
      Pretty Blood: "Pretty Blood",
      Requests: "Requests",
      Safe: "Safe",
      Shipping: "Shipping",
      SMG4: "SMG4",
      Sprunki: "Sprunki",
      The Amazing Digital Circus: "The Amazing Digital Circus",
    ]
  end

  def types do
    [
      "Sketch",
      "Colored Sketch",
      "Inked",
      "Flat Color",
      "Vector",
      "Cel Shaded",
      "Fully Shaded",
      "Traditional",
      "Pixel Art",
      "Animation - 2D",
      "Animation - CGI/3D",
      "Crafted Item",
      "Sculpture",
      "Plushie",
      "Trading Card",
      "Others"
    ]
  end
end
