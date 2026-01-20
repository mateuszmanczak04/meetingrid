up:
	mix deps.get
	mix ecto.migrate

server:
	iex -S mix phx.server

check: 
	MIX_ENV=test mix format --check-formatted
	MIX_ENV=test mix compile --warnings-as-errors
	MIX_ENV=test mix test
	MIX_ENV=test mix dialyzer
