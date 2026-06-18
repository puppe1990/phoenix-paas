defmodule PhoenixPaasWeb.UserSessionHTML do
  use PhoenixPaasWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:phoenix_paas, PhoenixPaas.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
