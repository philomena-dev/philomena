defmodule PhilomenaWeb.CaptchaView do
  use PhilomenaWeb, :view

  def hcaptcha_site_key do
    Application.get_env(:philomena, :hcaptcha_site_key)
  end
end
