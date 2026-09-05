defmodule Philomena.JobQueue do
  @moduledoc """
  The application boundary for enqueueing Oban jobs.

  Jobs keep their existing positional argument shape inside the serialized
  `args` field so the worker modules can continue to expose their direct
  `perform/*` functions for synchronous use and tests.
  """

  @doc "Enqueues a worker with positional arguments on the requested queue."
  @spec enqueue(module(), String.t() | atom(), list()) :: :ok
  def enqueue(worker, queue, args) do
    worker.new(%{"args" => args}, queue: queue)
    |> Oban.insert!()

    :ok
  end
end
