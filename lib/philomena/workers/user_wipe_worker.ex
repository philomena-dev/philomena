defmodule Philomena.UserWipeWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users.UserWipe
  alias Philomena.Multi

  @spec put_enqueue(Multi.t(), function()) :: Multi.t()
  def put_enqueue(%Multi{} = multi, user_id) when is_function(user_id, 1) do
    Philomena.JobQueue.put_enqueue(multi, __MODULE__, fn changes ->
      %{user_id: user_id.(changes)}
    end)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    UserWipe.perform(user_id)
  end
end
