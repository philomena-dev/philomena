defmodule PhilomenaWeb.ErrorView do
  use PhilomenaWeb, :view

  import PhilomenaWeb.LayoutView, only: [viewport_meta_tag: 1]

  @codes %{
    400 => {"Bad Request", "Couldn't process your request!"},
    403 => {"Forbidden", "Not allowed to access this page (are your cookies enabled?)"},
    404 => {"Not Found", "Couldn't find what you were looking for!"},
    500 => {"Internal Error", "Couldn't process your request!"}
  }

  def render(template, assigns) when template != "show.html" do
    {short_msg, long_msg} = @codes[assigns.status] || @codes[500]

    case Phoenix.Controller.get_format(assigns.conn) do
      "json" ->
        %{"error" => short_msg}

      _ ->
        render(
          PhilomenaWeb.ErrorView,
          "show.html",
          conn: assigns.conn,
          status: assigns.status,
          short_msg: short_msg,
          long_msg: long_msg
        )
    end
  end
end
