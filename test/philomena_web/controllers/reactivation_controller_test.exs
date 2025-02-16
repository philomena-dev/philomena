defmodule PhilomenaWeb.ReactivationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

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

      {:ok, email} = Users.deliver_user_reactivation_instructions(user, &url(~p"/reactivations/#{&1}"))
      {token, url} = extract_reactivation_link_from_email(email)

      assert token != nil
      assert url != nil

      conn = post(conn, url, %{"token" => token})
      assert redirected_to(conn) == ~p"/"

      user = Users.get_user!(user.id)
      assert user.deleted_by_user_id == nil
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
