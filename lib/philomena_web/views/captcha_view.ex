defmodule PhilomenaWeb.CaptchaView do
  use PhilomenaWeb, :view

  # Prevent ID collisions if multiple forms are on the page.
  def challenge_name do
    Integer.to_string(:rand.uniform(1024))
  end

  def hcaptcha_site_key do
    Application.get_env(:philomena, :hcaptcha_site_key)
  end
end
