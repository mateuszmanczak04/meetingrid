defmodule CoreWeb.Live.Hooks.UserAuth do
  use CoreWeb, :verified_routes

  import Phoenix.Component
  import Phoenix.LiveView

  alias Core.Auth

  def on_mount(:require_current_user, _params, %{"current_user_id" => current_user_id}, socket) do
    case Auth.get_user(current_user_id) do
      nil ->
        {:halt, redirect(socket, to: ~p"/")}

      current_user ->
        {:cont, assign(socket, :current_user, current_user)}
    end
  end
end
