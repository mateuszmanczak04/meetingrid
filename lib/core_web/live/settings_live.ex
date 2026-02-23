defmodule CoreWeb.SettingsLive do
  use CoreWeb, :live_view
  alias Core.Auth
  alias Core.Meetings

  @impl true
  def mount(_params, %{"user" => current_user}, socket) do
    form =
      current_user
      |> Auth.change_user()
      |> to_form()

    {:ok, assign(socket, current_user: current_user, form: form)}
  end

  @impl true
  def handle_event("validate", %{"user" => attrs}, socket) do
    form =
      socket.assigns.current_user
      |> Auth.change_user(attrs)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("submit", %{"user" => attrs}, socket) do
    case Auth.update_user(socket.assigns.current_user, attrs) do
      {:ok, user} ->
        Enum.each(
          Meetings.list_user_meetings(socket.assigns.current_user),
          &Meetings.MeetingServer.reload_and_broadcast_if_running(&1.id)
        )

        {:noreply,
         socket
         |> assign(:current_user, user)
         |> put_flash(:info, "Settings updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> put_flash(:error, "Something went wrong")}
    end
  end
end
