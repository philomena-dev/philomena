defmodule PhilomenaWeb.ReactivationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Repo
  alias Philomena.Users.UserToken
  alias Philomena.Users
  import Philomena.UsersFixtures

  setup do
    %{user: deactivated_user_fixture()}
  end

  @host PhilomenaWeb.Endpoint.config(:url)[:host]
  @port PhilomenaWeb.Endpoint.config(:http)[:port]

  describe "GET /reactivations/:id" do
    test "renders the reactivate account page", %{conn: conn} do
      conn = get(conn, ~p"/reactivations/pinkie-pie-is-best-pony")
      response = html_response(conn, 200)
      assert response =~ "<h1>Reactivate Your Account</h1>"
    end
  end

  describe "POST /reactivations/" do
    test "reactivate account page works", %{conn: conn, user: user} do
      {:ok, email} =
        Users.deliver_user_reactivation_instructions(user, &url(~p"/reactivations/#{&1}"))

      assert UserToken.user_and_contexts_query(user, ["reactivate"]) |> Repo.exists?()

      {token, url} = extract_reactivation_link_from_email(email)

      assert token != nil
      assert url != nil

      conn = post(conn, url, %{"token" => token})
      assert redirected_to(conn) == ~p"/"

      user = Users.get_user!(user.id)
      assert user.deleted_by_user_id == nil

      assert not(UserToken.user_and_contexts_query(user, ["reactivate"]) |> Repo.exists?())
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
