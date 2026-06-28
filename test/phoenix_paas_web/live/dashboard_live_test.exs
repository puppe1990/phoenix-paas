defmodule PhoenixPaasWeb.DashboardLiveTest do
  use PhoenixPaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PhoenixPaas.TenancyFixtures
  alias PhoenixPaasWeb.UserAuth

  setup :register_and_log_in_user

  test "redirects when not logged in" do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(build_conn(), ~p"/")
  end

  test "renders dashboard when only remember-me cookie is present", %{user: user} do
    logged_in_conn =
      build_conn()
      |> Map.replace!(:secret_key_base, PhoenixPaasWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> fetch_cookies()
      |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

    %{value: signed_token} = logged_in_conn.resp_cookies["_phoenix_paas_web_user_remember_me"]

    conn =
      logged_in_conn
      |> recycle()
      |> Map.replace!(:secret_key_base, PhoenixPaasWeb.Endpoint.config(:secret_key_base))
      |> put_req_cookie("_phoenix_paas_web_user_remember_me", signed_token)
      |> init_test_session(%{user_remember_me: true})

    refute get_session(conn, :user_token)

    {:ok, view, html} = live(conn, ~p"/")
    assert has_element?(view, "#dashboard")
    assert html =~ "Phoenix PaaS"
  end

  test "renders dashboard when only user_id is present in session", %{user: user} do
    conn =
      build_conn()
      |> init_test_session(%{user_id: user.id})

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#dashboard")
  end

  test "renders dashboard overview for tenant", %{conn: conn, scope: scope} do
    server =
      TenancyFixtures.server_fixture(scope, %{name: "lightsail-1", host_ip: "100.59.80.29"})

    TenancyFixtures.app_fixture(scope, server, %{
      name: "Trip Planner",
      slug: "trip-planner",
      github_repo: "puppe1990/trip-planner-ia-phx",
      host: "trip.gestaobem.com"
    })

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#dashboard")
    assert render(view) =~ "Trip Planner"
  end

  test "does not show other tenant apps", %{conn: conn, scope: scope} do
    other = TenancyFixtures.scope_fixture()
    server = TenancyFixtures.server_fixture(other)

    TenancyFixtures.app_fixture(other, server, %{
      name: "Secret App",
      slug: "secret",
      github_repo: "other/secret",
      host: "secret.example.com"
    })

    {:ok, view, _html} = live(conn, ~p"/")
    refute render(view) =~ "Secret App"
    assert scope.tenant.id != other.tenant.id
  end
end
