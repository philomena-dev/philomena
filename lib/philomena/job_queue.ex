defmodule Philomena.JobQueue do
  @moduledoc """
  The application boundary for enqueueing Oban jobs.

  Job arguments are JSON-safe maps so they can be consumed directly by the
  worker modules and remain self-documenting when inspected in Oban.
  """

  alias Philomena.Multi

  @doc "Adds a worker insert to a Philomena.Multi."
  @spec put_enqueue(
          Multi.t(),
          module(),
          map() | (Ecto.Multi.changes() -> map()),
          keyword() | (Ecto.Multi.changes() -> keyword())
        ) :: Multi.t()
  def put_enqueue(%Multi{multi: ecto_multi} = multi, worker, args, opts \\ []) do
    changeset = fn changes ->
      args = if is_function(args, 1), do: args.(changes), else: args
      opts = if is_function(opts, 1), do: opts.(changes), else: opts
      worker.new(args, opts)
    end

    %{multi | multi: Oban.insert(ecto_multi, {:oban, make_ref()}, changeset)}
  end

  @doc "Inserts a worker immediately for standalone operations."
  @spec insert(module(), map(), keyword()) :: :ok
  def insert(worker, args, opts \\ []) do
    args
    |> worker.new(opts)
    |> Oban.insert!()

    :ok
  end
end
