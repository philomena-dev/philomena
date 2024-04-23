defmodule Philomena.Channels.PomfChannel do
  @api_online "https://pomf.tv/api/streams/getinfo.php?data=onlinestreams"

  @spec live_channels(DateTime.t()) :: map()
  def live_channels(now) do
    @api_online
    |> Philomena.Http.get()
    |> case do
      {:ok, %Tesla.Env{body: body, status: 200}} ->
        body
        |> Jason.decode!()
        |> Map.new(&{&1["onlinelist"], fetch(&1, now)})

      _error ->
        %{}
    end
  end

  defp fetch(api, now) do
    %{
      title: api["streamtitle"],
      is_live: true,
      nsfw: true,
      viewers: api["viewers"],
      thumbnail_url: api["profileimage"],
      last_fetched_at: now,
      last_live_at: now,
      description: api["streamdesc"]
    }
  end
end
