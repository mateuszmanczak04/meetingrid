defmodule CoreWeb.Router do
  use CoreWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CoreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug CoreWeb.Plugs.RequireCurrentUser
  end

  scope "/", CoreWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/privacy", PageController, :privacy

    scope "/meetings", Meetings do
      live "/", IndexLive
      live "/new", NewLive

      scope "/" do
        pipe_through [CoreWeb.Plugs.RequireMeeting]
        live "/:id", ShowLive
        live "/:id/invite", InviteLive
        live "/:id/join", JoinLive
      end
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:core, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CoreWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
