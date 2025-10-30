defmodule Philomena.FooterLinks.Link do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.FooterLinks.Category

  schema "footer_links" do
    belongs_to :category, Category

    field :title, :string
    field :url, :string
    field :position, :integer
    field :bold, :boolean, default: false
    field :new_tab, :boolean, default: false
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:title, :url, :category_id, :position, :bold, :new_tab])
  end
end
