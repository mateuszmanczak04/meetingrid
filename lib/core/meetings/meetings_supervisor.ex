defmodule Core.Meetings.MeetingsSupervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {
        Registry,
        name: Core.Meetings.MeetingServer.registry_name(), keys: :unique
      },
      {
        DynamicSupervisor,
        name: Core.Meetings.MeetingServer.dynamic_supervisor_name(), strategy: :one_for_one
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
