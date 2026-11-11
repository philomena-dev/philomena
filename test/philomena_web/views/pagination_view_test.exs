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

    assert html =~ ~s(<a class="pagination-link js-prev" href="/images?page=1">)
    assert html =~ ~s(<span class="pagination-link current" aria-current="page">2</span>)
    assert html =~ ~s(<a class="pagination-link js-next" href="/images?page=3">)
  end

  test "shows the steps past either end as unavailable" do
    first = render_pagination(1, 2)
    last = render_pagination(2, 2)

    refute first =~ "js-prev"
    assert first =~ ~s(<span class="pagination-link"><span class="pagination-icon">)
    refute last =~ "js-next"
    assert last =~ ~s(<span class="pagination-link">Next<span class="pagination-icon">)
  end

  test "keeps only the steps and the current page on narrow screens" do
    html = render_pagination(10, 20)

    assert html =~ ~s(<span class="pagination-gap hidden-below-md">…</span>)
    assert html =~ ~s(<a class="pagination-link hidden-below-md" href="/images?page=9">9</a>)
    assert html =~ ~s(<a class="pagination-link" href="/images?page=20">Last)
  end

  test "keeps the listing's query parameters in page links" do
    assert render_pagination(1, 2, params: [q: "safe"]) =~
             ~s(<a class="pagination-link js-next" href="/images?page=2&amp;q=safe">)
  end

  test "treats nil parameters as none" do
    assert render_pagination(1, 2, params: nil) =~
             ~s(<a class="pagination-link js-next" href="/images?page=2">)
  end

  test "renders nothing for a listing that fits on one page" do
    assert render_pagination(1, 1) == ""
  end
end
