defmodule Philomena.QuickTags do
  import Ecto.Query, warn: false
  alias Philomena.Repo
  alias Philomena.QuickTags.Default
  alias Philomena.QuickTags.Season
  alias Philomena.QuickTags.Shipping
  alias Philomena.QuickTags.ShorthandCategory
  alias Philomena.QuickTags.Shorthand
  alias Philomena.QuickTags.Tab

  def get_tabs() do
    Repo.all(Tab)
  end

  def get_shorthand_categories() do
    ShorthandCategory
    |> preload(:quick_tag_tab)
    |> Repo.all()
  end

  def get_shorthand_tags() do
    Shorthand
    |> preload(:shorthand_category)
    |> Repo.all()
  end

  def get_default_tags() do
    Default
    |> preload(:quick_tag_tab)
    |> Repo.all()
  end

  def get_season_tags() do
    Season
    |> preload(:quick_tag_tab)
    |> Repo.all()
  end

  def get_shipping_tags() do
    Shipping
    |> preload(:quick_tag_tab)
    |> Repo.all()
  end
end
