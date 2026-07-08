defmodule PhilomenaWeb.AdvertControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AdvertsFixtures

  describe "GET /adverts/:id" do
    test "redirects anonymous users to the advert's external link", %{conn: conn} do
      advert = advert_fixture()

      conn = get(conn, ~p"/adverts/#{advert}")

      # NOTE: the click is recorded asynchronously (Adverts.Server batches
      # updates every 10 seconds), so there is no synchronous side effect
      # to assert on. The eventual flush runs outside the SQL sandbox,
      # where this advert row doesn't exist, so ~10s into the test run the
      # GenServer logs a not_null_violation crash and restarts — harmless
      # noise, same category as the async-upload OwnershipError.
      assert redirected_to(conn) == advert.link
    end

    test "redirects logged-in users to the advert's external link", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      advert = advert_fixture()

      conn = get(conn, ~p"/adverts/#{advert}")

      assert redirected_to(conn) == advert.link
    end

    test "redirects to / for an unknown advert", %{conn: conn} do
      conn = get(conn, ~p"/adverts/999999999")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "raises for a non-integer advert id", %{conn: conn} do
      assert_raise Ecto.Query.CastError, ~r/cannot be cast to type :id/, fn ->
        get(conn, ~p"/adverts/not-a-number")
      end
    end
  end
end
