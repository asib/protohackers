defmodule EchoServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "7")

    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: EchoServer.ClientSupervisor},
      {EchoServer, [port: port]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EchoServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
