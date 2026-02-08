defmodule Core.GenServerCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Core.Repo
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Core.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Core.Repo, {:shared, self()})
  end
end
