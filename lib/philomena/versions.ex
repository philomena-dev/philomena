defmodule Philomena.Versions do
  @moduledoc """
  The Versions context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo
  alias Philomena.Versions.Difference

  @doc """
  Calculate a list of `m:Philomena.Versions.Difference` structs that represent
  paginated differences between different versions of the object.

  When expanded, the list of differences may look like:

      [
        %Difference{
          previous_version: %CommentVersion{},
          parent: %Comment{},
          user: %User{},
          difference: [del: "goodbye ", ins: "hello ", eq: "world"],
        }
      ]

  ## Examples

      iex> compute_text_differences(CommentVersion, %Comment{}, :body, page: 1, page_size: 25)
      %Scrivener.Page{}

  """
  def compute_text_differences(query, parent, name, pagination) do
    page = Repo.paginate(preload_and_order(query), pagination)
    initial = get_comparison_version(query, parent, page)

    {differences, _prev} =
      Enum.map_reduce(page, initial, fn older, newer ->
        d = %Difference{
          previous_version: newer,
          created_at: older.created_at,
          parent: parent,
          user: older.user,
          difference: difference(older, newer, name)
        }

        {d, older}
      end)

    %{page | entries: differences}
  end

  #
  # Get the first version to use when reducing the list of differences.
  #
  defp get_comparison_version(query, parent, page) do
    curr = Enum.at(page, 0)

    prev =
      if curr do
        query
        |> where([v], v.created_at > ^curr.created_at and v.id > ^curr.id)
        |> order_by(asc: :created_at, asc: :id)
        |> limit(1)
        |> Repo.one()
      end

    prev || parent
  end

  defp preload_and_order(query) do
    query
    |> preload(:user)
    |> order_by(desc: :created_at, desc: :id)
  end

  defp difference(curr, prev, name) do
    curr_body = Map.fetch!(curr, name)
    prev_body = Map.fetch!(prev, name)

    String.myers_difference(curr_body, prev_body)
  end
end
