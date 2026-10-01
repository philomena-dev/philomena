defmodule Philomena.Images.Search.Scope do
  @moduledoc """
  The image search scope: the compiled filter, search parameters, and the
  default pagination window. The actor is passed separately to operations
  that need authorization or viewer-specific behavior.

  Built once by the caller and passed to every image search function. Search
  parameters are cast into the typed fields `q`, `sf`, `sd`, `sort`, `del`,
  `hidden`, and `rel`; invalid values are discarded by `new/3`. `filter` is
  the compiled OpenSearch query body of the viewer's active filter and is
  excluded from every result set.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          filter: map(),
          pagination: PhilomenaQuery.Search.pagination_params()
        }

  embedded_schema do
    field :filter, :map, virtual: true
    field :pagination, :map, virtual: true

    field :q, :string
    field :sf, :string
    field :sd, :string
    field :sort, {:array, :string}
    field :del, :string
    field :hidden, :boolean
    field :rel, :string
  end

  @spec new(map(), PhilomenaQuery.Search.pagination_params(), map()) :: t()
  def new(filter, pagination, attrs \\ %{})
      when is_map(filter) and is_map(pagination) do
    scope =
      %__MODULE__{
        filter: filter,
        pagination: pagination
      }

    scope
    |> cast(attrs, [:q, :sf, :sd, :sort, :del, :hidden, :rel])
    |> then(&keep_valid(scope, &1))
    |> apply_action!(:create)
  end

  defp keep_valid(scope, %Ecto.Changeset{changes: changes, errors: errors}) do
    error_keys = Keyword.keys(errors)
    valid_changes = Map.drop(changes, error_keys)

    change(scope, valid_changes)
  end
end
