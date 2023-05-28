defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do

    with port_string when not is_nil(port_string) <- System.get_env("PORT"),
         port <- String.to_integer(port_string),
         app_name when not is_nil(app_name) <- System.get_env("APP_NAME") do

        client_handler = Module.concat([Protohackers, app_name, Client])
        children = [
          {Protohackers.Server, [port: port, client_handler: client_handler]}
        ]

        opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
        Supervisor.start_link(children, opts)
      else
        _ -> {:error, "Must specify PORT and APP_NAME"}
    end

  end
end
