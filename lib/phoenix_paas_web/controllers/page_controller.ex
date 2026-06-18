defmodule PhoenixPaasWeb.PageController do
  use PhoenixPaasWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/")
  end
end
