defmodule PhilomenaWeb.ImageUpdater do
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Ecto.Query
  
  
  
  defp init do
	Process.register(self(), :image_updater)
	run()
  end
  
  def cast(image_id) when type in [:impression] do
    pid = Process.whereis(:image_updater)
	if pid, do: send(pid, {image_id})
  end
  
  defp run do
    # Read view counts from mailbox
    views = receive_all()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Create insert statements for Ecto
    views = Enum.map(views, &views_insert_all(&1, now))

    # Merge into table
    views_update = update(Image, inc: [views: fragment("EXCLUDED.views")])

    Repo.insert_all(Image, views, on_conflict: views_update, conflict_target: [:id])

    :timer.sleep(:timer.seconds(10))

    run()
  end

  defp receive_all(views \\ %{}) do
    receive do
      image_id ->
        views = Map.update(views, image_id, 1, &(&1 + 1))
        receive_all(views)
    after
      0 ->
        views
    end
  end

  defp views_insert_all({image_id, views}, now) do
    %{
      id: image_id,
      views: views,
      created_at: now,
      updated_at: now
    }
  end
end