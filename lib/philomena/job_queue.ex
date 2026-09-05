defmodule Philomena.JobQueue do
  @moduledoc """
  The application boundary for enqueueing Oban jobs.

  Job arguments are JSON-safe maps so they can be consumed directly by the
  worker modules and remain self-documenting when inspected in Oban.
  """

  @doc "Enqueues a worker with arguments and optional Oban options."
  @spec enqueue(module(), map(), keyword()) :: :ok
  def enqueue(worker, args, opts \\ []) do
    args
    |> worker.new(opts)
    |> Oban.insert!()

    :ok
  end
end
