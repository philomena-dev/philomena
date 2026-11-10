defmodule PhilomenaWeb.PaginationViewTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.PaginationView

  defp render_pagination(page_number, total_pages, assigns \\ []) do
    page = %Scrivener.Page{
      entries: [],
      page_number: page_number,
      page_size: 25,
      total_entries: total_pages * 25,
      total_pages: total_pages
    }

    route = fn params -> "/images?" <> URI.encode_query(params) end

    Phoenix.View.render_to_string(
      PaginationView,
      "_pagination.html",
      [page: page, route: route] ++ assigns
    )
  end

  test "links the other pages of a listing without extra parameters" do
    html = render_pagination(2, 3)

    assert html =~ ~s(<a class="js-prev" href="/images?page=1">)
    assert html =~ ~s(<span class="page-current">2</span>)
    assert html =~ ~s(<a class="js-next" href="/images?page=3">)
  end

  test "renders nothing for a search that fits on one page" do
    assert render_pagination(1, 1, params: [q: "safe"]) == ""
  end
end
