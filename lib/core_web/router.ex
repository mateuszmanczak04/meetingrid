defmodule CoreWeb.Router do
  use CoreWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CoreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", CoreWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/privacy", PageController, :privacy

    scope "/" do
      pipe_through [CoreWeb.Plugs.RequireCurrentUserId]

      live_session :authenticated,
        on_mount: {CoreWeb.Live.Hooks.UserAuth, :require_current_user} do
        live "/settings", SettingsLive

        live "/meetings/", Meetings.IndexLive
        live "/meetings/new", Meetings.NewLive
        live "/meetings/:id", Meetings.ShowLive
        live "/meetings/:id/edit", Meetings.EditLive
        live "/meetings/:id/invite", Meetings.InviteLive
        live "/meetings/:id/join", Meetings.JoinLive
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
