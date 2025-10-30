defmodule Philomena.FooterLinks do
  import Ecto.Query, warn: false
  alias Philomena.Repo
  alias Philomena.FooterLinks.Category
  alias Philomena.FooterLinks.Link

  def get_categories() do
    Repo.all(Category)
  end

  def get_links() do
    Link
    |> preload(:category)
    |> Repo.all()
  end

  def get_footer_data() do
    categories =
      Repo.all(
        from c in Category,
          order_by: c.position
      )

    links =
      Repo.all(
        from l in Link,
          order_by: l.position
      )

    links_by_category = Enum.group_by(links, & &1.category_id)

    Enum.map(categories, fn category ->
      %{
        title: category.title,
        links: Map.get(links_by_category, category.id, [])
      }
    end)
  end
end
