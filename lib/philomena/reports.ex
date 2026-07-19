defmodule Philomena.Reports do
  @moduledoc """
  The Reports context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias PhilomenaQuery.Batch
  alias PhilomenaQuery.Search
  alias Philomena.Reports.Report
  alias Philomena.Reports
  alias Philomena.IndexWorker
  alias Philomena.Rules

  alias Philomena.Images.Image
  alias Philomena.Comments.Comment
  alias Philomena.Posts.Post
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Galleries.Gallery

  @reason_regex ~r/^(Rule|Other|Takedown|Verification|Approval|Review|System)([^:]*): (.*)$/

  @doc """
  Returns the current number of open reports.

  If the user is allowed to view reports, returns the current count.
  If the user is not allowed to view reports, returns `nil`.

  ## Examples

      iex> count_reports(%User{})
      nil

      iex> count_reports(%User{role: "admin"})
      4

  """
  def count_open_reports(user) do
    if Canada.Can.can?(user, :index, Report) do
      Report
      |> where(open: true)
      |> Repo.aggregate(:count)
    else
      nil
    end
  end

  @doc """
  Returns the list of reports.

  ## Examples

      iex> list_reports()
      [%Report{}, ...]

  """
  def list_reports do
    Repo.all(Report)
  end

  @doc """
  Gets a single report.

  Raises `Ecto.NoResultsError` if the Report does not exist.

  ## Examples

      iex> get_report!(123)
      %Report{}

      iex> get_report!(456)
      ** (Ecto.NoResultsError)

  """
  def get_report!(id), do: Repo.get!(Report, id)

  @doc """
  Creates a report against the target named by `target`, a one-entry keyword
  list of the target foreign key column and its id (e.g. `[image_id: image.id]`).

  ## Examples

      iex> create_report([image_id: image.id], attribution, %{"reason" => "..."})
      {:ok, %Report{}}

      iex> create_report([image_id: image.id], attribution, %{"reason" => ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_report(target, attribution, attrs \\ %{}) do
    rule = Rules.find_rule(attrs["rule_id"])

    struct(Report, target)
    |> Report.user_creation_changeset(attrs, attribution, rule)
    |> Repo.insert()
    |> reindex_after_update()
  end

  @doc """
  Returns an `m:Ecto.Query` which updates all open reports against the target
  named by `target`, a one-entry keyword list of the target foreign key column
  and its id (e.g. `[image_id: image.id]`), to close them.

  Because this is only a query due to the limitations of `m:Ecto.Multi`, this must be
  coupled with an associated call to `reindex_reports/1` to operate correctly, e.g.:

      report_query = Reports.close_report_query([image_id: image.id], user)

      Multi.new()
      |> Multi.update_all(:reports, report_query, [])
      |> Repo.transaction()
      |> case do
        {:ok, %{reports: {_count, reports}} = result} ->
          Reports.reindex_reports(reports)

          {:ok, result}

        error ->
          error
      end

  Use `close_reports/2` to close and reindex reports in one step outside an `m:Ecto.Multi`.

  ## Examples

      iex> close_report_query([image_id: 1], %User{})
      #Ecto.Query<...>

  """
  def close_report_query([{column, id}], closing_user) do
    now = DateTime.utc_now(:second)

    from r in Report,
      where: field(r, ^column) == ^id and r.open == true,
      select: r.id,
      update: [
        set: [
          open: false,
          state: "closed",
          admin_id: ^closing_user.id,
          updated_at: ^now
        ]
      ]
  end

  @doc """
  Closes all open reports against the target named by `target` (see
  `close_report_query/2`), marking them as closed by the specified user.
  Also reindexes the affected reports.

  Returns `{:ok, {count, reports}}`.
  """
  def close_reports(target, closing_user) do
    {_count, reports} =
      result = Repo.update_all(close_report_query(target, closing_user), [])

    reindex_reports(reports)
    {:ok, result}
  end

  @doc """
  Automatically create a report with the given rule and reason against the
  target named by `target`, a one-entry keyword list of the target foreign key
  column and its id (e.g. `[comment_id: comment.id]`).

  ## Examples

      iex> create_system_report([comment_id: 1], "Rule #0", "Custom report reason")
      {:ok, %Report{}}

  """
  def create_system_report(target, rule_name, reason) do
    rule = Rules.get_by_name!(rule_name)

    attrs = %{
      reason: reason,
      user_agent: "system"
    }

    attribution = %{
      system: true,
      ip: %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32},
      fingerprint: "ffff"
    }

    struct(Report, target)
    |> Report.creation_changeset(attrs, attribution, rule)
    |> Repo.insert()
    |> reindex_after_update()
  end

  @doc """
  Updates a report.

  ## Examples

      iex> update_report(report, %{field: new_value})
      {:ok, %Report{}}

      iex> update_report(report, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_report(%Report{} = report, attrs) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Deletes a Report.

  ## Examples

      iex> delete_report(report)
      {:ok, %Report{}}

      iex> delete_report(report)
      {:error, %Ecto.Changeset{}}

  """
  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking report changes.

  ## Examples

      iex> change_report(report)
      %Ecto.Changeset{source: %Report{}}

  """
  def change_report(%Report{} = report) do
    Report.changeset(report, %{})
  end

  @doc """
  Marks the report as claimed by the given user.

  ## Example

      iex> claim_report(%Report{}, %User{})
      {:ok, %Report{}}

  """
  def claim_report(%Report{} = report, user) do
    report
    |> Report.claim_changeset(user)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Marks the report as unclaimed.

  ## Example

      iex> unclaim_report(%Report{})
      {:ok, %Report{}}

  """
  def unclaim_report(%Report{} = report) do
    report
    |> Report.unclaim_changeset()
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Marks the report as closed by the given user.

  ## Example

      iex> close_report(%Report{}, %User{})
      {:ok, %Report{}}

  """
  def close_report(%Report{} = report, user) do
    report
    |> Report.close_changeset(user)
    |> Repo.update()
    |> reindex_after_update()
  end

  @doc """
  Reindex all reports where the user or admin has `old_name`.

  ## Example

      iex> user_name_reindex("Administrator", "Administrator2")
      {:ok, %Req.Response{}}

  """
  def user_name_reindex(old_name, new_name) do
    data = Reports.SearchIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Report, data.query, data.set_replacements, data.replacements)
  end

  defp reindex_after_update({:ok, report}) do
    reindex_report(report)

    {:ok, report}
  end

  defp reindex_after_update(result) do
    result
  end

  @doc """
  Callback for post-transaction update.

  See `close_report_query/2` for more information and example.
  """
  def reindex_reports(report_ids) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Reports", "id", report_ids])

    report_ids
  end

  @doc false
  def reindex_report(%Report{} = report) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Reports", "id", [report.id]])

    report
  end

  @doc false
  def perform_reindex(column, condition) do
    Report
    |> where([r], field(r, ^column) in ^condition)
    |> preload([:user, :admin])
    |> Repo.all()
    |> preload_reportable()
    |> Enum.map(&Search.index_document(&1, Report))
  end

  @doc """
  Preloads the target associations onto the given report(s) and populates
  the virtual `reportable` field with the resolved target struct.
  """
  def preload_reportable(%Report{} = report) do
    [report] = preload_reportable([report])
    report
  end

  def preload_reportable(reports) do
    reports
    |> Enum.to_list()
    |> Repo.preload(Report.reportable_preloads())
    |> Enum.map(&%{&1 | reportable: Report.reportable(&1)})
  end

  def indexing_preloads do
    [
      :user,
      :admin,
      :reported_user,
      image: from(i in Image, preload: :user),
      comment: from(c in Comment, preload: :user),
      post: from(p in Post, preload: :user),
      commission: from(x in Commission, preload: :user),
      conversation: from(c in Conversation, preload: [:from, :to]),
      gallery: from(g in Gallery, preload: :user)
    ]
  end

  def convert_reports!() do
    rules =
      Rules.list_reportable_rules()
      |> Enum.map(&{&1.name, &1})
      |> Map.new()

    Report
    |> preload([:rule])
    |> Batch.records(batch_size: 128)
    |> Enum.each(&convert_report(&1, rules))
  end

  defp convert_report(%Report{rule_id: 1, reason: report_reason} = report, rules) do
    match = Regex.run(@reason_regex, report_reason)

    case match do
      [_, prefix, suffix, reason] ->
        rule =
          case Map.get(rules, "#{prefix}#{suffix}") do
            nil -> %{id: 1}
            rule -> rule
          end

        report
        |> Report.conversion_changeset(%{reason: String.trim(reason)}, rule)
        |> Repo.update!()

      _ ->
        {:error, report}
    end
  end

  defp convert_report(report, _rules), do: {:ok, report}
end
