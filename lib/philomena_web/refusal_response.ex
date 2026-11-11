defmodule PhilomenaWeb.RefusalResponse do
  @moduledoc """
  Renders the response for a write refused with a flash message, such as a
  rate limit or a failed captcha.

  AJAX requests get an empty 300 response (ujs.ts reloads the page so the
  flash renders); everything else is redirected to `return_to`, by default
  the referrer.
  """

  alias Plug.Conn
  alias Phoenix.Controller

  @spec call(Plug.Conn.t(), String.t(), String.t() | nil) :: Plug.Conn.t()
  def call(conn, message, return_to \\ nil) do
    conn = Controller.put_flash(conn, :error, message)

    if conn.assigns.ajax? do
      conn
      |> Conn.send_resp(:multiple_choices, "")
      |> Conn.halt()
    else
      conn
      |> Controller.redirect(external: return_to || conn.assigns.referrer)
      |> Conn.halt()
    end
  end
end
