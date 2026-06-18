defmodule PhoenixPaasWeb.PageControllerTest do
  use PhoenixPaasWeb.ConnCase

  import PhoenixPaasWeb.ConnCase, only: [log_in_user: 2]
  import PhoenixPaas.AccountsFixtures

  test "GET / redirects to login when unauthenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "GET / renders dashboard when authenticated", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/")

    assert html_response(conn, 200) =~ "Phoenix PaaS"
  end
end
