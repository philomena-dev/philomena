defmodule PhilomenaWeb.IpProfile.SourceChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.SourceChanges.SourceChange
  alias Philomena.SpoilerExecutor
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  def index(conn, %{"ip_profile_id" => ip}) do
    {:ok, ip} = EctoNetwork.INET.cast(ip)

    source_changes =
      SourceChange
      |> where(ip: ^ip)
      |> order_by(desc: :created_at)
      |> preload([:user, image: [:user]])
      |> Repo.paginate(conn.assigns.scrivener)

    spoilers =
      SpoilerExecutor.execute_spoiler(
        conn.assigns.compiled_spoiler,
        Enum.map(source_changes, & &1.image)
      )

    render(conn, "index.html",
      title: "Source Changes for IP `#{ip}'",
      ip: ip,
      source_changes: source_changes,
      spoilers: spoilers
    )
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :show, :ip_address) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
