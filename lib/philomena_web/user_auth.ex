defmodule PhilomenaWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Philomena.Users
  alias PhilomenaWeb.Router.Helpers, as: Routes
  alias PhilomenaWeb.UserIpUpdater
  alias PhilomenaWeb.UserFingerprintUpdater

  # Make the remember me cookie valid for 365 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 365
  @remember_me_cookie "user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]
  @totp_auth_cookie "user_totp_auth"
  @totp_auth_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Users.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  @doc """
  Writes TOTP session metadata for an authenticated user.
  """
  def totp_auth_user(conn, user, params \\ %{}) do
    token = Users.generate_user_totp_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> put_session(:totp_token, token)
    |> maybe_write_totp_auth_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_totp_auth_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @totp_auth_cookie, token, @totp_auth_options)
  end

  defp maybe_write_totp_auth_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Users.delete_session_token(user_token)

    totp_token = get_session(conn, :totp_token)
    totp_token && Users.delete_totp_token(totp_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      PhilomenaWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> delete_resp_cookie(@totp_auth_cookie)
    |> redirect(to: "/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    {totp_token, conn} = ensure_totp_token(conn)

    user = user_token && Users.get_user_by_session_token(user_token)
    totp = totp_token && Users.user_totp_token_valid?(user, totp_token)

    cond do
      user && user.otp_required_for_login && totp ->
        update_usages(conn, user)

      user && !user.otp_required_for_login ->
        update_usages(conn, user)

      true ->
        nil
    end

    conn
    |> assign(:current_user, user)
    |> assign(:totp_valid?, totp)
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if user_token = conn.cookies[@remember_me_cookie] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  defp ensure_totp_token(conn) do
    if totp_token = get_session(conn, :totp_token) do
      {totp_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@totp_auth_cookie])

      if totp_token = conn.cookies[@totp_auth_cookie] do
        {totp_token, put_session(conn, :totp_token, totp_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: Routes.session_path(conn, :new))
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET", request_path: request_path} = conn) do
    put_session(conn, :user_return_to, request_path)
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: "/"

  defp update_usages(conn, user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    conn = fetch_cookies(conn)

    UserIpUpdater.cast(user.id, conn.remote_ip, now)
    UserFingerprintUpdater.cast(user.id, conn.cookies["_ses"], now)
  end
end
