defmodule Philomena.Users.UserNotifier do
  alias Bamboo.Email
  alias Philomena.Mailer

  defp deliver(to, subject, body) do
    Email.new_email(
      to: to,
      from: mailer_address(),
      subject: subject,
      body: body
    )
    |> Mailer.deliver_later()
  end

  defp mailer_address do
    Application.get_env(:philomena, :mailer_address)
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions for your account", """

    ==============================

    Hi #{user.name},

    You can confirm your account by visiting the url below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset password account.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Password reset instructions for your account", """

    ==============================

    Hi #{user.name},

    You can reset your password by visiting the url below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update your e-mail.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "E-mail update instructions for your account", """

    ==============================

    Hi #{user.name},

    You can change your e-mail by visiting the url below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
