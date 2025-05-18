defmodule Philomena.Test.Pagination do
  @type page_params() :: [
          page: non_neg_integer(),
          page_size: non_neg_integer()
        ]

  @type load_page_fn(t) :: (page_params() -> Scrivener.Page.t(t))

  @spec load_all(load_page_fn(t), page_params()) :: [t]
        when t: var
  def load_all(load_page, page_params \\ []) do
    load_all_recurse(load_page, page_params, [])
  end

  @spec load_all_recurse(load_page_fn(t), page_params(), [t]) :: [t]
        when t: var
  defp load_all_recurse(load_page, page_params, acc) do
    page = load_page.(page_params)
    acc = acc ++ page.entries

    if page.page_number >= page.total_pages do
      acc
    else
      next_page_params = Keyword.put(page_params, :page, page.page_number + 1)
      load_all_recurse(load_page, next_page_params, acc)
    end
  end
end
