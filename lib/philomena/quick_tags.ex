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

  @doc """
  Builds a structured representation of quick tags for display.
  Returns tabs with their associated data in the natural database structure.
  """
  def build_quick_tag_structure() do
    tabs =
      get_tabs()
      |> Enum.sort_by(& &1.position)

    defaults = get_default_tags()
    seasons = get_season_tags()
    categories = get_shorthand_categories()
    shorthands = get_shorthand_tags()
    shippings = get_shipping_tags()

    # Group data by tab
    tabs_with_data =
      tabs
      |> Enum.map(fn tab ->
        %{
          tab: tab,
          mode: determine_tab_mode(tab, defaults, seasons, categories, shippings),
          defaults: Enum.filter(defaults, &(&1.quick_tag_tab_id == tab.id)),
          seasons: Enum.filter(seasons, &(&1.quick_tag_tab_id == tab.id)),
          categories: Enum.filter(categories, &(&1.quick_tag_tab_id == tab.id)),
          shippings: Enum.filter(shippings, &(&1.quick_tag_tab_id == tab.id))
        }
      end)

    # Get all tag names for lookup
    tag_names = extract_all_tag_names(defaults, seasons, shorthands)

    {tabs_with_data, tag_names, shorthands}
  end

  defp determine_tab_mode(tab, defaults, seasons, categories, shippings) do
    cond do
      Enum.any?(defaults, &(&1.quick_tag_tab_id == tab.id)) -> :default
      Enum.any?(seasons, &(&1.quick_tag_tab_id == tab.id)) -> :season
      Enum.any?(categories, &(&1.quick_tag_tab_id == tab.id)) -> :shorthand
      Enum.any?(shippings, &(&1.quick_tag_tab_id == tab.id)) -> :shipping
      true -> :default
    end
  end

  defp extract_all_tag_names(defaults, seasons, shorthands) do
    default_tags = Enum.flat_map(defaults, & &1.tags)
    season_tags = Enum.map(seasons, & &1.tag)
    shorthand_tags = Enum.map(shorthands, & &1.tag)

    (default_tags ++ season_tags ++ shorthand_tags)
    |> Enum.uniq()
  end
end
