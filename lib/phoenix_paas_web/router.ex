defmodule PhoenixPaasWeb.Router do
  use PhoenixPaasWeb, :router

  import PhoenixPaasWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixPaasWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :github_webhook do
    plug :accepts, ["json"]
  end

  scope "/webhooks", PhoenixPaasWeb do
    pipe_through :github_webhook

    post "/github", GithubWebhookController, :create
  end

  scope "/", PhoenixPaasWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated,
      on_mount: [
        {PhoenixPaasWeb.UserAuth, :mount_current_scope},
        {PhoenixPaasWeb.UserAuth, :require_authenticated},
        {PhoenixPaasWeb.PaasMount, :default}
      ] do
      live "/", DashboardLive, :index
      live "/servers", ServerLive.Index, :index
      live "/servers/new", ServerLive.Index, :new
      live "/servers/:id", ServerLive.Show, :show
      live "/apps", AppLive.Index, :index
      live "/apps/new", AppLive.Index, :new
      live "/apps/:id", AppLive.Show, :show
    end
  end

  if Application.compile_env(:phoenix_paas, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhoenixPaasWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", PhoenixPaasWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", PhoenixPaasWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", PhoenixPaasWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
