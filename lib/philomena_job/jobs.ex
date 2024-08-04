defmodule PhilomenaJob.Jobs do
  @moduledoc """
  The Jobs context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi

  @doc """
  Return a `m:Ecto.Multi` to create a job from the `:id` key of a previous operation.

  This function automatically raises an error when a deadlock condition could be created.
  When inserting into multiple tables in the same transaction, you must run job creation in
  order of the creating module name.

  On successful completion, the table is notified for new work.

  ## Example

      Multi.new()
      |> Multi.insert(:image, image_changeset)
      |> Jobs.create_job_from_op(ImageIndexRequest, :image, %{index_type: "update"})
      |> Repo.transaction()
      |> case do
        {:ok, %{image: image}} ->
          {:ok, image}

        _ ->
          {:error, image_changeset}
      end

  """
  def create_job_from_op(multi, job_module, key, map \\ %{}) do
    [primary_key] = job_module.__schema__(:primary_key)
    job_update = update(job_module, set: [request_time: fragment("EXCLUDED.request_time")])

    multi
    |> Multi.run({:lock_table, job_module}, lock_table(job_module))
    |> Multi.run({:insert, job_module}, fn repo, %{^key => %{id: id}} ->
      entry =
        Map.merge(map, %{
          primary_key => id,
          request_time: DateTime.utc_now()
        })

      result =
        repo.insert_all(
          job_module,
          [entry],
          on_conflict: job_update,
          conflict_target: primary_key
        )

      {:ok, result}
    end)
    |> Multi.run({:notify, job_module}, notify_table(job_module))
    |> avoid_deadlock()
  end

  @doc """
  Return a `m:Ecto.Multi` to bulk create and notify jobs from an input query.

  Due to [this Ecto bug](https://github.com/elixir-ecto/ecto/issues/4430), the caller must
  select the fields needed for the table insert to succeed. The input query should look like:

      job_query =
        from i in Image,
          where: ...,
          select: %{
            image_id: i.id,
            request_time: ^DateTime.utc_now(),
            index_type: "update"
          }

  This function automatically raises an error when a deadlock condition could be created.
  When inserting into multiple tables in the same transaction, you must run job creation in
  order of the creating module name.

  On successful completion, the table is notified for new work.

  ## Example

      Multi.new()
      |> Multi.update_all(:images, images, [])
      |> Jobs.create_jobs_from_query(ImageIndexRequest, job_query)
      |> Repo.transaction()
      |> case do
        {:ok, %{images: images}} ->
          {:ok, images}

        _ ->
          {:error, ...}
      end

  """
  def create_jobs_from_query(multi \\ Multi.new(), job_module, query) do
    primary_key = job_module.__schema__(:primary_key)
    job_update = update(job_module, set: [request_time: fragment("EXCLUDED.request_time")])

    multi
    |> Multi.run({:lock_table, job_module}, lock_table(job_module))
    |> Multi.insert_all({:insert, job_module}, job_module, query,
      on_conflict: job_update,
      conflict_target: primary_key
    )
    |> Multi.run({:notify, job_module}, notify_table(job_module))
    |> avoid_deadlock()
  end

  @doc """
  Return a `m:Ecto.Multi` to fetch and assign `limit` number of free jobs.

  Jobs can be ordered by request_time `:asc` (default) or `:desc`. This can
  be used e.g. to have workers sample from both ends of the queue.

  Results are returned in the `jobs` key of the multi. The table is not notified
  for new work.

  ## Example

      ImageIndexRequest
      |> Jobs.fetch_and_assign_jobs("images_0", 500, :desc)
      |> Repo.transaction()
      |> case do
        {:ok, %{jobs: {_, jobs}}} ->
          {:ok, jobs}

        _ ->
          {:error, :job_assignment_failed}
      end

  """
  def fetch_and_assign_jobs(job_module, worker_name, limit, order \\ :asc) do
    update_query =
      from job in job_module,
        where: is_nil(job.worker_name),
        limit: ^limit,
        order_by: [{^order, :request_time}],
        update: [set: [worker_name: ^worker_name]],
        select: job

    Multi.new()
    |> Multi.run(:lock_table, lock_table(job_module))
    |> Multi.update_all(:jobs, update_query, [])
  end

  @doc """
  Return a `m:Ecto.Multi` to release all jobs with the given worker name.

  On successful completion, the table is notified for new work.

  ## Example

      ImageIndexRequest
      |> Jobs.release_jobs("images_0")
      |> Repo.transaction()

  """
  def release_jobs(job_module, worker_name) do
    update_query =
      from job in job_module,
        where: job.worker_name == ^worker_name,
        update: [set: [worker_name: nil]]

    Multi.new()
    |> Multi.run(:lock_table, lock_table(job_module))
    |> Multi.update_all(:update, update_query, [])
    |> Multi.run(:notify, notify_table(job_module))
  end

  @doc """
  Return a `m:Ecto.Multi` to complete all jobs in the list of jobs.

  Jobs where the request time is identical to the fetched job are deleted
  entirely. Jobs where the request time is newer than the fetched job are
  updated to reset their attempt count.

  On successful completion, the table is notified for new work.

  ## Example

      ImageIndexRequest
      |> Jobs.complete_jobs(jobs)
      |> Repo.transaction()

  """
  def complete_jobs(job_module, jobs) do
    [primary_key] = job_module.__schema__(:primary_key)

    delete_query = where(job_module, fragment("'t' = 'f'"))

    delete_query =
      Enum.reduce(jobs, delete_query, fn job, query ->
        or_where(
          query,
          [q],
          field(q, ^primary_key) == ^Map.fetch!(job, primary_key) and
            q.request_time == ^job.request_time
        )
      end)

    job_keys = Enum.map(jobs, &Map.fetch!(&1, primary_key))

    update_query =
      from job in job_module,
        where: field(job, ^primary_key) in ^job_keys,
        update: [set: [attempt_count: 0, worker_name: nil]]

    Multi.new()
    |> Multi.run(:lock_table, lock_table(job_module))
    |> Multi.delete_all(:delete, delete_query)
    |> Multi.update_all(:update, update_query, [])
    |> Multi.run(:notify, notify_table(job_module))
  end

  @doc """
  Return a `m:Ecto.Multi` to fail the given job, incrementing its attempt
  counter.

  On successful completion, the table is notified for new work.

  ## Example

      ImageIndexRequest
      |> Jobs.fail_job(job)
      |> Repo.transaction()

  """
  def fail_job(job_module, job) do
    [primary_key] = job_module.__schema__(:primary_key)

    update_query =
      from q in job_module,
        where: field(q, ^primary_key) == ^Map.fetch!(job, primary_key),
        update: [inc: [attempt_count: 1], set: [worker_name: nil]]

    Multi.new()
    |> Multi.run(:lock_table, lock_table(job_module))
    |> Multi.update_all(:update, update_query, [])
    |> Multi.run(:notify, notify_table(job_module))
  end

  defp avoid_deadlock(multi) do
    table_lock_operations =
      multi
      |> Multi.to_list()
      |> Enum.flat_map(fn
        {{:lock_table, name}, _} -> [name]
        _ -> []
      end)

    if table_lock_operations != Enum.sort(table_lock_operations) do
      raise "Table lock operations do not occur in sorted order.\n" <>
              "Got: #{inspect(table_lock_operations)}\n" <>
              "Sort the lock operations to prevent deadlock."
    else
      multi
    end
  end

  defp lock_table(job_module) do
    fn repo, _changes ->
      repo.query("LOCK TABLE $1 IN EXCLUSIVE MODE", [table_name(job_module)])
    end
  end

  defp notify_table(job_module) do
    fn repo, _changes ->
      repo.query("NOTIFY $1", [table_name(job_module)])
    end
  end

  defp table_name(job_module) do
    job_module.__schema__(:source)
  end
end
