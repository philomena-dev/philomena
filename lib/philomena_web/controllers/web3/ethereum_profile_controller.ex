defmodule PhilomenaWeb.EthereumProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, params) do

    user =
      User
      |> where(ethereum: ^conn.params["id"])
      |> Repo.one()

    if user do

      if user.slug do

        if conn.params["page"] != "api" do
          conn
          |> redirect(to: "/profiles/" <> user.slug)
        else

          api_version = "1"
          if !is_nil(conn.params["api_version"]) do
            api_version = conn.params["api_version"]
          end

          conn
          |> redirect(to: "/api/v#{api_version}/json/profiles/#{user.id}")

        end

      else
        conn
        |> redirect(to: "/")
      end
    else
      conn
      |> redirect(to: "/")
    end

  end
end
