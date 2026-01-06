defmodule CoreWeb.Meetings.Guards do
  defguard is_admin(socket)
           when socket.assigns.current_attendee.role == :admin
end
