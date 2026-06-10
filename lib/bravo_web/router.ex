defmodule BravoWeb.Router do
  use BravoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BravoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BravoWeb do
    pipe_through :browser

    get "/register", RegistrationController, :new
    post "/register", RegistrationController, :create
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete

    live_session :authenticated,
      on_mount: {BravoWeb.Auth.SessionHooks, :require_authenticated} do
      live "/", DashboardLive, :index
    end
  end

  # Prometheus metrics scrape endpoint (no pipeline: returns plain text).
  scope "/", BravoWeb do
    get "/metrics", MetricsController, :index
  end

  scope "/api", BravoWeb do
    pipe_through :api

    post "/auth/token", AuthController, :token
  end

  scope "/api", BravoWeb do
    pipe_through [:api, BravoWeb.Auth.Plug]

    resources "/credit_requests", CreditRequestController, except: [:new, :edit]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:bravo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BravoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
