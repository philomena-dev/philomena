defmodule Philomena.TagChangeRevertWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  @moduledoc """
  Reverts every tag change made by a user, IP, or fingerprint, batching by
  image so each image's tag history is reverted in a single operation.
  """

  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  import Ecto.Query

  @spec enqueue(map(), map()) :: :ok
  def enqueue(target, attributes) when is_map(target) and is_map(attributes) do
    Philomena.JobQueue.enqueue(__MODULE__, Map.put(target, :attributes, attributes))
  end

  @impl Oban.Worker
  def perform(job)

  def perform(%Oban.Job{args: %{"user_id" => user_id, "attributes" => attributes}}) do
    TagChange
    |> where(user_id: ^user_id)
    |> revert_all(attributes)
  end

  def perform(%Oban.Job{args: %{"ip" => ip, "attributes" => attributes}}) do
    TagChange
    |> where(ip: ^ip)
    |> revert_all(attributes)
  end

  def perform(%Oban.Job{args: %{"fingerprint" => fp, "attributes" => attributes}}) do
    TagChange
    |> where(fingerprint: ^fp)
    |> revert_all(attributes)
  end

  defp revert_all(queryable, attributes) do
    attributes = cast_ip(atomify_keys(attributes))

    TagChanges.revert_all_for_worker(queryable, attributes)
  end

  defp atomify_keys(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  end

  defp cast_ip(attributes) do
    %{attributes | ip: elem(EctoNetwork.INET.cast(attributes[:ip]), 1)}
  end
end
