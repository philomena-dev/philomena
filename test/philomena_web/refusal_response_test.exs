defmodule PhilomenaWeb.RefusalResponseTest do
  use PhilomenaWeb.ConnCase, async: true

  alias PhilomenaWeb.RefusalResponse

  defp refuse(ajax?) do
    build_conn()
    |> put_req_header("referer", "/images/1")
    |> init_test_session(%{})
    |> fetch_flash()
    |> PhilomenaWeb.ReferrerPlug.call([])
    |> assign(:ajax?, ajax?)
    |> RefusalResponse.call("Slow down.")
  end

  test "an AJAX write gets an empty 300 so the script reloads into the flash" do
    conn = refuse(true)

    assert conn.halted
    assert response(conn, 300) == ""
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Slow down."
  end

  test "any other write is sent back to the referrer with the flash" do
    conn = refuse(false)

    assert conn.halted
    assert redirected_to(conn) == "/images/1"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Slow down."
  end
end
