defmodule Philomena.Schema.Search do
  alias Philomena.Images.Query
  alias PhilomenaQuery.Parse.String
  import Ecto.Changeset

  def validate_search(changeset, field, user, watched \\ false) do
    query = changeset |> get_field(field) |> String.normalize()
    output = Query.compile(user, query, watched)

    case output do
      {:ok, _} ->
        changeset

      _ ->
        add_error(changeset, field, "is invalid")
    end
  end
end
