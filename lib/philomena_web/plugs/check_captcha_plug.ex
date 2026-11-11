defmodule PhilomenaWeb.CheckCaptchaPlug do
  alias PhilomenaWeb.RefusalResponse

  def init([]), do: false

  def call(conn, _opts) do
    if captcha_enabled?() do
      maybe_check_captcha(conn, conn.assigns.current_user)
    else
      conn
    end
  end

  defp maybe_check_captcha(conn, nil) do
    if valid_solution?(conn.params) do
      conn
    else
      RefusalResponse.call(
        conn,
        "There was an error verifying you're not a robot. Please try again."
      )
    end
  end

  defp maybe_check_captcha(conn, _user), do: conn

  defp valid_solution?(%{"h-captcha-response" => captcha_token}) when is_binary(captcha_token) do
    with {:ok, %{body: body, status: 200}} <-
           PhilomenaProxy.Http.post(
             "https://hcaptcha.com/siteverify",
             URI.encode_query(%{"response" => captcha_token, "secret" => hcaptcha_secret_key()}),
             [{"Content-Type", "application/x-www-form-urlencoded"}]
           ),
         {:ok, %{"success" => true}} <- JSON.decode(body) do
      true
    else
      _ -> false
    end
  end

  defp valid_solution?(_params), do: false

  def captcha_enabled? do
    Application.get_env(:philomena, :captcha) != false
  end

  def hcaptcha_secret_key do
    Application.get_env(:philomena, :hcaptcha_secret_key)
  end
end
