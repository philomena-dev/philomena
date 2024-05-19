defmodule PhilomenaWeb.AdvertController do
  use PhilomenaWeb, :controller

  alias Philomena.Adverts.{Advert, Updater}

  plug :load_resource, model: Advert

  def show(conn, _params) do
    advert = conn.assigns.advert

    Updater.cast(:click, advert.id)

    redirect(conn, external: advert.link)
  end
end
