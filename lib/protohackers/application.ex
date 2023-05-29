defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    with {:ok, port_string} <- fetch_env("PORT"),
         port <- String.to_integer(port_string),
         {:ok, app_name} <- fetch_env("APP_NAME"),
         client_handler_name <- Module.concat([Protohackers, Macro.camelize(app_name), Client]),
         {:module, client_handler_module} <- ensure_compiled(client_handler_name) do
      socket_opts =
        case Kernel.function_exported?(client_handler_module, :server_socket_opts, 0) do
          true -> Kernel.apply(client_handler_module, :server_socket_opts, [])
          false -> []
        end

      children =
        case Kernel.function_exported?(client_handler_module, :udp_server, 0) do
          true ->
            [{Protohackers.UDPServer, [port: port, client_handler: client_handler_module]}]

          false ->
            [
              {Protohackers.TCPServer,
               [port: port, client_handler: client_handler_module, socket_opts: socket_opts]}
            ]
        end

      opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end

  defp fetch_env(var_name) do
    case System.fetch_env(var_name) do
      :error -> {:error, "#{var_name} not found"}
      ok -> ok
    end
  end

  defp ensure_compiled(module_name) do
    case Code.ensure_compiled(module_name) do
      {:error, err} -> {:error, "could not load client handler module #{module_name}: #{err}"}
      ok -> ok
    end
  end
end
