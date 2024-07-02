defmodule PhilomenaWeb.AdvertPlug do
  alias Philomena.Adverts
  alias Plug.Conn

  def init([]), do: []

  def call(conn, _opts) do
    user = conn.assigns.current_user
    image = conn.assigns[:image]
    show_ads? = show_ads?(user)

    maybe_assign_ad(conn, image, show_ads?)
  end

  defp maybe_assign_ad(conn, image, show_ads?)

  defp maybe_assign_ad(conn, nil, true),
    do: Conn.assign(conn, :advert, record_impression(Adverts.random_live()))

  defp maybe_assign_ad(conn, image, true),
    do: Conn.assign(conn, :advert, record_impression(Adverts.random_live(image)))

  defp maybe_assign_ad(conn, _image, _false),
    do: Conn.assign(conn, :advert, nil)

  defp show_ads?(%{hide_advertisements: hide}),
    do: !hide

  defp show_ads?(_user),
    do: true

  defp record_impression(nil), do: nil

  defp record_impression(advert) do
    Adverts.record_impression(advert)

    advert
  end
end
