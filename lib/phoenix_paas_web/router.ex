defmodule PhoenixPaasWeb.Router do
  use PhoenixPaasWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixPaasWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :github_webhook do
    plug :accepts, ["json"]
  end

  scope "/", PhoenixPaasWeb do
    pipe_through :browser

    live_session :default, on_mount: {PhoenixPaasWeb.PaasMount, :default} do
      live "/", DashboardLive, :index
      live "/servers", ServerLive.Index, :index
      live "/servers/new", ServerLive.Index, :new
      live "/apps", AppLive.Index, :index
      live "/apps/new", AppLive.Index, :new
      live "/apps/:id", AppLive.Show, :show
    end
  end

  scope "/webhooks", PhoenixPaasWeb do
    pipe_through :github_webhook

    post "/github", GithubWebhookController, :create
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhoenixPaasWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:phoenix_paas, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhoenixPaasWeb.Telemetry
    end
  end
end
