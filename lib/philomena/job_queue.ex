defmodule Philomena.JobQueue do
  @moduledoc """
  The application boundary for enqueueing Oban jobs.

  Job arguments are JSON-safe maps so they can be consumed directly by the
  worker modules and remain self-documenting when inspected in Oban.
  """

  @doc "Enqueues a worker with arguments on the requested queue."
  @spec enqueue(module(), String.t() | atom(), map()) :: :ok
  def enqueue(worker, queue, args) do
    worker.new(args, queue: queue)
    |> Oban.insert!()

    :ok
  end
end
