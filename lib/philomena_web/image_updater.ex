defmodule PhilomenaWeb.ImageUpdater do
  alias Philomena.Images.Image
  alias Philomena.Repo
  alias Philomena.Images.ImageView
  import Ecto.Query
  
  def child_spec([]) do
    %{
      id: PhilomenaWeb.ImageUpdater,
      start: {PhilomenaWeb.ImageUpdater, :start_link, [[]]}
    }
  end

  def start_link([]) do
    {:ok, spawn_link(&init/0)}
  end
  
  defp init do
	Process.register(self(), :image_updater)
	run()
  end
  
  def cast(image_id) do
    pid = Process.whereis(:image_updater)
	if pid, do: send(pid, image_id)
  end
  
  defp run do
    # Read view counts from mailbox
    views_count = receive_all()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Create insert statements for Ecto
    views_count = Enum.map(views_count, &views_insert_all(&1, now))

    # Merge into table
    views_update = update(ImageView, inc: [views_count: fragment("EXCLUDED.views_count")])

    Repo.insert_all(ImageView, views_count, on_conflict: views_update, conflict_target: [:id])

    :timer.sleep(:timer.seconds(10))

    run()
  end

  defp receive_all(views_count \\ %{}) do
    receive do
      image_id ->
        views_count = Map.update(views_count, image_id, 1, &(&1 + 1))
        receive_all(views_count)
    after
      0 ->
        views_count
    end
  end

  defp views_insert_all({image_id, views_count}, now) do
    %{
      id: image_id,
      views_count: views_count,
      created_at: now,
      updated_at: now
    }
  end
end