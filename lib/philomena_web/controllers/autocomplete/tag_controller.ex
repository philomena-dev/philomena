defmodule PhilomenaWeb.Autocomplete.TagController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.Search
  alias Philomena.Tags.Tag
  import Ecto.Query

  def show(conn, %{"vsn" => "2"} = params), do: show_v2(conn, params)
  def show(conn, params), do: show_v1(conn, params)

  defp show_v2(conn, params) do
    with {:ok, term} <- extract_term_v2(params),
         {:ok, limit} <- extract_limit(params) do
      suggestions = search(term, limit)
      json(conn, %{suggestions: suggestions})
    else
      {:error, message} ->
        json(conn, %{message: message})
    end
  end

  defp extract_term_v2(%{"term" => term}) when is_binary(term) and byte_size(term) > 2 do
    result =
      term
      |> String.downcase()
      |> String.trim()

    {:ok, result}
  end

  defp extract_term_v2(%{"term" => _}),
    do: {:error, "Term is too short, must be at least 3 characters"}

  defp extract_term_v2(_params), do: {:error, "Term is missing"}

  defp extract_limit(params) do
    limit =
      params
      |> Map.get("limit", "10")
      |> Integer.parse()

    case limit do
      {limit, ""} when limit > 0 and limit <= 10 ->
        {:ok, limit}

      _ ->
        {:error, "Limit must be an integer between 1 and 10"}
    end
  end

  @spec search(String.t(), integer()) :: [map()]
  defp search(term, limit) do
    Tag
    |> Search.search_definition(
      %{
        query: %{
          bool: %{
            should: [
              %{prefix: %{name: term}},
              %{prefix: %{name_in_namespace: term}}
            ]
          }
        },
        sort: %{images: :desc}
      },
      %{page_size: 10}
    )
    |> Search.search_records(preload(Tag, :aliased_tag))
    |> Enum.map(
      &%{
        :alias => if(is_nil(&1.aliased_tag), do: nil, else: &1.name),
        canonical: if(is_nil(&1.aliased_tag), do: &1.name, else: &1.aliased_tag.name),
        images: if(is_nil(&1.aliased_tag), do: &1.images_count, else: &1.aliased_tag.images_count),
        id: &1.id
      }
    )
    |> Enum.uniq_by(& &1.id)
    |> Enum.filter(&(&1.images > 0))
    |> Enum.sort_by(&(-&1.images))
    |> Enum.take(limit)
    |> Enum.map(
      &%{
        :alias => &1.alias,
        canonical: &1.canonical,
        images: &1.images
      }
    )
  end

  # Version 1 is kept for backwards compatibility with the older versions of
  # the frontend application that may still be cached in user's browsers.
  defp show_v1(conn, params) do
    tags =
      case extract_term(params) do
        nil ->
          []

        term ->
          search(term, 5)
          |> Enum.map(&%{label: "#{&1.canonical} (#{&1.images})", value: &1.canonical})
      end

    conn
    |> json(tags)
  end

  defp extract_term(%{"term" => term}) when is_binary(term) and byte_size(term) > 2 do
    term
    |> String.downcase()
    |> String.trim()
  end

  defp extract_term(_params), do: nil
end
