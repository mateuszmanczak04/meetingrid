defmodule CoreWeb.Meetings.NewLive do
  use CoreWeb, :live_view
  alias Core.Meetings

  @impl true
  def mount(_params, _session, socket) do
    # TODO: use full changeset for all fields, not only title
    data = %{}
    types = %{title: :binary}
    params = %{title: ""}

    form =
      {data, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))
      |> Ecto.Changeset.validate_required(Map.keys(types))
      |> to_form(as: :meeting)

    {:ok, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("validate", %{"meeting" => attrs}, socket) do
    data = %{}
    types = %{title: :binary}

    form =
      {data, types}
      |> Ecto.Changeset.cast(attrs, Map.keys(types))
      |> Ecto.Changeset.validate_required(Map.keys(types))
      |> to_form(as: :meeting, action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("submit", %{"meeting" => %{"title" => title}} = attrs, socket) do
    # TODO
    attrs = attrs |> Map.drop(["meeting"]) |> Map.put("title", title)

    case Meetings.create_meeting(socket.assigns.current_user, attrs) do
      {:ok, attendee} ->
        {:noreply, push_navigate(socket, to: ~p"/meetings/#{attendee.meeting.id}")}

      {:error, _} ->
        # Basic HTML validations shouldn't allow to even get here
        {:noreply, put_flash(socket, :error, "Something went wrong. Please try again")}
    end
  end
end
