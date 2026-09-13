defmodule Philomena.DuplicateReports.QueryBuilder do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DuplicateReports.QueryForm

  @doc """
  Builds the staff duplicate-report query for the given parameters.

  ## Parameters

    * `states` - Filter by duplicate-report states; the default includes open
      and claimed reports

  Returns `{:ok, query, query_form}` with a queryable that can be used with
  `Repo.paginate/2`, or `{:error, changeset}` if the provided parameters are
  invalid.
  """
  @spec build_query(map()) ::
          {:ok, Ecto.Query.t(), QueryForm.t()} | {:error, Ecto.Changeset.t()}
  def build_query(params \\ %{}) do
    with {:ok, query_form} <-
           %QueryForm{}
           |> QueryForm.changeset(params)
           |> Ecto.Changeset.apply_action(:create) do
      query =
        DuplicateReport
        |> where([report], report.state in ^query_form.states)
        |> order_by([report], desc: report.created_at, desc: report.id)

      {:ok, query, query_form}
    end
  end
end
