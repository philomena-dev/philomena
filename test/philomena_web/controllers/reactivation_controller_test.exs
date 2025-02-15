defmodule PhilomenaWeb.ReactivationControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  import Philomena.TestUtilities

  alias Swoosh.Adapters.Local.Storage.Memory
  alias Philomena.Users

  setup :register_and_log_in_user

  @host PhilomenaWeb.Endpoint.config(:url)[:host]
  @port PhilomenaWeb.Endpoint.config(:http)[:port]

  describe "GET /reactivations/:id" do
    test "renders the reactivate account page", %{conn: conn} do
      conn = delete(conn, ~p"/deactivations")
      conn = get(conn, ~p"/reactivations/pinkie-pie-is-best-pony")
      response = html_response(conn, 200)
      assert response =~ "<h1>Reactivate Your Account</h1>"
    end
  end

  describe "POST /reactivations/" do
    test "reactivate account page works", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/deactivations")

      {token, url} =
        Memory.all()
        |> Enum.find(&(&1.subject == "Reactivation instructions for your account"))
        |> extract_reactivation_link_from_email()

      assert token != nil
      assert url != nil

      conn = post(conn, url, %{"token" => token})
      assert redirected_to(conn) == ~p"/"

      assert_retry(fn ->
        user = Users.get_user!(user.id)
        user.deleted_by_user_id == nil
      end)
    end
  end

  defp extract_reactivation_link_from_email(email = %Swoosh.Email{}) do
    %{"token" => token, "url" => url} =
      Regex.named_captures(
        ~r/(?<url>http:\/\/#{@host}:#{@port}\/reactivations)\/(?<token>.*)/,
        email.text_body
      )

    {token, url}
  end
end
